/*
 * Copyright (C) 2016 Open Source Robotics Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
*/

#include <memory>
#include <functional>

#ifdef _WIN32
  #include <Winsock2.h>
  #include <Ws2def.h>
  #include <Ws2ipdef.h>
  #include <Ws2tcpip.h>
  using raw_type = char;
#else
  #include <sys/socket.h>
  #include <netinet/in.h>
  #include <netinet/tcp.h>
  #include <arpa/inet.h>
  using raw_type = void;
#endif

#if defined(_MSC_VER)
  #include <BaseTsd.h>
  typedef SSIZE_T ssize_t;
#endif

#include <fcntl.h>
#include <gazebo/sensors/RaySensor.hh>

#include "include/ArduPilotTeraRangerEvoPlugin.hh"

using namespace gazebo;
GZ_REGISTER_SENSOR_PLUGIN(ArduPilotTeraRangerEvoPlugin)

namespace gazebo
{
  class ArduPilotTeraRangerEvoPluginPrivate
  {
    /// \brief Pointer to the parent ray sensor
    public: sensors::RaySensorPtr parentSensor;

    /// \brief All event connections.
    public: std::vector<event::ConnectionPtr> connections;

    /// \brief TeraRanger Tower Evo address
    public: std::string terarangerevo_addr;

    /// \brief TeraRanger Tower Evo port for receiver socket
    public: uint16_t terarangerevo_port;

    public: int handle;

    public: struct terarangerevoPacket
            {
              uint64_t timestamp;
              float target[8];
            };
  };
}

/////////////////////////////////////////////////
ArduPilotTeraRangerEvoPlugin::ArduPilotTeraRangerEvoPlugin()
    : SensorPlugin(),
      dataPtr(new ArduPilotTeraRangerEvoPluginPrivate)
{
  // socket
  this->dataPtr->handle = socket(AF_INET, SOCK_DGRAM /*SOCK_STREAM*/, 0);
  #ifndef _WIN32
  // Windows does not support FD_CLOEXEC
  fcntl(this->dataPtr->handle, F_SETFD, FD_CLOEXEC);
  #endif
  int one = 1;
  setsockopt(this->dataPtr->handle, IPPROTO_TCP, TCP_NODELAY,
      reinterpret_cast<const char *>(&one), sizeof(one));
  setsockopt(this->dataPtr->handle, SOL_SOCKET, SO_REUSEADDR,
      reinterpret_cast<const char *>(&one), sizeof(one));

  #ifdef _WIN32
  u_long on = 1;
  ioctlsocket(this->dataPtr->handle, FIONBIO,
      reinterpret_cast<u_long FAR *>(&on));
  #else
  fcntl(this->dataPtr->handle, F_SETFL,
      fcntl(this->dataPtr->handle, F_GETFL, 0) | O_NONBLOCK);
  #endif
}

/////////////////////////////////////////////////
ArduPilotTeraRangerEvoPlugin::~ArduPilotTeraRangerEvoPlugin()
{
  this->dataPtr->connections.clear();
  this->dataPtr->parentSensor.reset();
}

/////////////////////////////////////////////////
void ArduPilotTeraRangerEvoPlugin::Load(sensors::SensorPtr _sensor,
                                        sdf::ElementPtr _sdf)
{
  this->dataPtr->parentSensor =
    std::dynamic_pointer_cast<sensors::RaySensor>(_sensor);

  if (!this->dataPtr->parentSensor)
  {
    gzerr << "ArduPilotTeraRangerEvoPlugin not attached to a ray sensor\n";
    return;
  }

  this->dataPtr->terarangerevo_addr =
          _sdf->Get("terarangerevo_addr", static_cast<std::string>("127.0.0.1")).first;
  this->dataPtr->terarangerevo_port =
          _sdf->Get("terarangerevo_port", 9006).first;

  this->dataPtr->parentSensor->SetActive(true);

  this->dataPtr->connections.push_back(this->dataPtr->parentSensor->ConnectUpdated(
      std::bind(&ArduPilotTeraRangerEvoPlugin::OnUpdate, this,
        this->dataPtr->parentSensor)));
}

/////////////////////////////////////////////////
void ArduPilotTeraRangerEvoPlugin::OnUpdate(sensors::RaySensorPtr _ray)
{
  std::vector<double> v(_ray->RangeCount());
  _ray->Ranges(v);

  // send_packet
  ArduPilotTeraRangerEvoPluginPrivate::terarangerevoPacket pkt;

  pkt.timestamp = static_cast<uint64_t>
    (1.0e3 * this->dataPtr->parentSensor->LastMeasurementTime().Double());
  pkt.target[0] = static_cast<float>(v[4]);
  pkt.target[1] = static_cast<float>(v[3]);
  pkt.target[2] = static_cast<float>(v[2]);
  pkt.target[3] = static_cast<float>(v[1]);
  pkt.target[4] = static_cast<float>(v[0]);
  pkt.target[5] = static_cast<float>(v[7]);
  pkt.target[6] = static_cast<float>(v[6]);
  pkt.target[7] = static_cast<float>(v[5]);

  struct sockaddr_in sockaddr;
  memset(&sockaddr, 0, sizeof(sockaddr));
  sockaddr.sin_port = htons(this->dataPtr->terarangerevo_port);
  sockaddr.sin_family = AF_INET;
  sockaddr.sin_addr.s_addr = inet_addr(this->dataPtr->terarangerevo_addr.c_str());
  ::sendto(this->dataPtr->handle,
           reinterpret_cast<raw_type *>(&pkt),
           sizeof(pkt), 0,
           (struct sockaddr *)&sockaddr, sizeof(sockaddr));
}
