--[[
    Copyright (c) 2020, Rhys Mainwaring

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

--[[
    Servo driver for LX16A serial bus servos

    Reference
    =========

    LewanSoul Bus Servo Communication Protocol
    https://www.dropbox.com/sh/b3v81sb9nwir16q/AABZRndzrcVjE1-Tbv-JmsAva/LX-16A%20Bus%20Servo/LewanSoul%20Bus%20Servo%20Communication%20Protocol.pdf?dl=0


    Bindings
    ========

    serial:begin(baudrate)
    serial:read()
    serial:write(byte)
    serial:available()
    serial:set_flow_control(enable)
    serial:find_serial(device_no)

--]]

-- servo outputs
local SERVO1_FUNCTION = 94      -- front_left_wheel_joint
local SERVO2_FUNCTION = 95      -- front_right_wheel_joint
local SERVO3_FUNCTION = 96      -- mid_left_wheel_joint
local SERVO4_FUNCTION = 97      -- mid_right_wheel_joint
local SERVO5_FUNCTION = 98      -- back_left_wheel_joint
local SERVO6_FUNCTION = 99      -- back_right_wheel_joint

local SERVO7_FUNCTION = 100     -- front_left_steer_joint
local SERVO8_FUNCTION = 101     -- front_right_steer_joint
local SERVO9_FUNCTION = 102     -- back_left_steer_joint
local SERVO10_FUNCTION = 103    -- back_right_steer_joint

-- constants
local SERVO_BUS_HEADER            = 0x55
local SERVO_BUS_MIN_ID            = 0x00
local SERVO_BUS_MAX_ID            = 0xFE
local SERVO_MOVE_TIME_WRITE       = 1     -- 0x01 move
local SERVO_OR_MOTOR_MODE_WRITE   = 29    -- 0x1D setMotorMode, setServoMode

-- update at 10Hz
local UPDATE_PERIOD = 100 -- milli-seconds

-- find the first serial port with SERIALX_PROTOCOL 28
local port = serial:find_serial(0)

if not port then
    gcs:send_text(0, "lx16a: no scripting serial port!")
    return
end

-- configure the serial port
port:begin(115200)
port:set_flow_control(0)

local function flush_read()
    local n_bytes = port:available()
    while n_bytes > 0 do
        port:read()
        n_bytes = n_bytes - 1
    end
end

local function write_packet(packet)
    -- gcs:send_text(6, "write_packet")

    if packet ~= nil and #packet > 0 then
        for i=1, #packet do
            local byte = tonumber(packet[i])
            port:write(byte)
            -- gcs:send_text(6, "byte[" .. tostring(i) .. "]: " .. byte)
        end
        return #packet
    else
        return -1
    end
end

local function checksum(servo_id, length, command, data)
    local cs = tonumber(servo_id) + tonumber(length) + tonumber(command)
    if data ~= nil and #data > 0 then
        for i=1, #data do
            cs = cs + tonumber(data[i])
        end
        cs = (~cs) & 0xff
    end
    return cs
end

local function make_packet(servo_id, length, command, data)
    -- gcs:send_text(6, "make_packet")

    -- packet header
    local packet = { SERVO_BUS_HEADER, SERVO_BUS_HEADER }

    -- check the servo id is in range
    if servo_id < SERVO_BUS_MIN_ID or servo_id > SERVO_BUS_MAX_ID then
        return -1
    end
    packet[#packet + 1] = servo_id

    -- check the data is consistent with the specified length
    local data_length = 0
    if data ~= nil then data_length = #data end
    if length ~= 3 + data_length then
        return -1
    end
    packet[#packet + 1] = length

    -- append command to packet
    packet[#packet + 1] = command

    -- append parameter data to packet
    if data ~= nil then
        for i = 1, #data do
            packet[#packet + 1] = data[i]
        end
    end

    -- calculate the checksum and append to packet
    local cs = checksum(servo_id, length, command, data)
    packet[#packet + 1] = cs

    return packet
end

local function send_command(servo_id, length, command, data)
    -- gcs:send_text(6, "send_command")

    -- create the packet
    local packet = make_packet(servo_id, length, command, data)
    if packet == -1 then
        gcs:send_text(0, "lx16a: error! (send_command)")
        return -1
    end

    -- flush buffers
    flush_read()

    -- send packet
    local bytes_sent = write_packet(packet)
    if bytes_sent == -1 then
        gcs:send_text(0, "lx16a: error! (send_command)")
        return -1
    end
    return bytes_sent
end

local function move_time_write(servo_id, servo_pos, move_time)
    local pos_lsb = servo_pos & 0xff
    local pos_hsb = (servo_pos >> 8) & 0xff
    local move_time_lsb = move_time & 0xff
    local move_time_hsb = (move_time >> 8) & 0xff
    local data = {pos_lsb, pos_hsb, move_time_lsb, move_time_hsb}
    local status = send_command(servo_id, 7, SERVO_MOVE_TIME_WRITE, data)
    if status == -1 then
        gcs:send_text(0, "lx16a: error! (move_time_write)")
    end
    return status
end

local function motor_mode_write(servo_id, duty)
    local duty_lsb = duty & 0xff
    local duty_hsb = (duty >> 8) & 0xff
    local data = {1, 0, duty_lsb, duty_hsb}
    local status = send_command(servo_id, 7, SERVO_OR_MOTOR_MODE_WRITE, data)
    if status == -1 then
        gcs:send_text(0, "lx16a: error! (motor_mode_write)")
    end
    return status
end

local function servo_mode_write(servo_id)
    local data = {0, 0, 0, 0}
    local status = send_command(servo_id, 7, SERVO_OR_MOTOR_MODE_WRITE, data)
    if status == -1 then
        gcs:send_text(0, "lx16a: error! (servo_mode_write)")
    end
    return status
end

local function set_wheel_servo(servo_id, servo_function)
    local servo_pwm = SRV_Channels:get_output_pwm(servo_function)

    -- initialisation / failsafe
    if servo_pwm == nil or servo_pwm < 500 then
        motor_mode_write(servo_id, 0)
        return
    end

    local servo_duty = 2.0 * (servo_pwm - 1500.0)
    servo_duty = math.max(math.min(servo_duty, 1000.0), -1000.0)
    servo_duty = math.floor(servo_duty)

    motor_mode_write(servo_id, servo_duty)
end

local function set_steer_servo(servo_id, servo_function)
    local servo_pwm = SRV_Channels:get_output_pwm(servo_function)

    -- initialisation / failsafe
    if servo_pwm == nil or servo_pwm < 500 then
        move_time_write(servo_id, 500, 50)
    end

    -- steering PWM in [1000, 2000] maps to [-180, 180]
    -- LX16A output [0, 1000] maps to [-135, 135]
    local deg = 180.0 * (servo_pwm - 1500.0) / 500.0
    local servo_pos = deg * 1000.0 / 270.0 + 500.0
    servo_pos = math.max(math.min(servo_pos, 1000.0), 0.0)
    servo_pos = math.floor(servo_pos)

    -- gcs:send_text(6, tonumber(servo_id) .. ": " .. tonumber(servo_pos))
    -- servo_mode_write(servo_id)
    move_time_write(servo_id, servo_pos, 50)
end

local function update()
    -- check the port is available
    if not port then
        gcs:send_text(0, "lx16a: no scripting serial port!")
        return update, UPDATE_PERIOD
    end

    -- wheel servos: duty in range [-1000, 1000]
    set_wheel_servo(11, SERVO1_FUNCTION)
    set_wheel_servo(21, SERVO2_FUNCTION)
    set_wheel_servo(12, SERVO3_FUNCTION)
    set_wheel_servo(22, SERVO4_FUNCTION)
    set_wheel_servo(13, SERVO5_FUNCTION)
    set_wheel_servo(23, SERVO6_FUNCTION)

    -- steering servos: position in range [0, 100]
    set_steer_servo(111, SERVO7_FUNCTION)
    set_steer_servo(211, SERVO8_FUNCTION)
    set_steer_servo(131, SERVO9_FUNCTION)
    set_steer_servo(231, SERVO10_FUNCTION)

    return update, UPDATE_PERIOD
end

gcs:send_text(6, "lx16a_servo_driver.lua is running")

-- set steering servos to position mode
servo_mode_write(111)
servo_mode_write(211)
servo_mode_write(131)
servo_mode_write(231)

return update(), 3000
