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

#ifndef _GAZEBO_ARDUPILOTTERARANGEREVO_PLUGIN_HH_
#define _GAZEBO_ARDUPILOTTERARANGEREVO_PLUGIN_HH_

#include <string>
#include <memory>

#include "gazebo/common/Plugin.hh"
#include "gazebo/util/system.hh"

namespace gazebo
{
  // Forward declare private class.
  class ArduPilotTeraRangerEvoPluginPrivate;

  /// \brief A TeraRanger Tower Evo plugin
  class GAZEBO_VISIBLE ArduPilotTeraRangerEvoPlugin : public SensorPlugin
  {
    /// \brief Constructor
    public: ArduPilotTeraRangerEvoPlugin();

    /// \brief Destructor
    public: virtual ~ArduPilotTeraRangerEvoPlugin();

    // Documentation Inherited.
    public: void Load(sensors::SensorPtr _sensor, sdf::ElementPtr _sdf);

    /// \brief Callback when new ray data is available
    /// \param[in] _ray ray sensor
    public: virtual void OnUpdate(sensors::RaySensorPtr _ray);

    /// \internal
    /// \brief Pointer to private data.
    private: std::unique_ptr<ArduPilotTeraRangerEvoPluginPrivate> dataPtr;
  };
}
#endif
