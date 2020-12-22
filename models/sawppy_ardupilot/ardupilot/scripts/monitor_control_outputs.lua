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
    Monitor high level control ouputs
--]]

-- control outputs
local CONTROL_OUTPUT_THROTTLE = 3
local CONTROL_OUTPUT_YAW = 4

-- update at 0.5Hz
local UPDATE_PERIOD = 2000

--[[
    Main update loop

    Poll the control outputs every UPDATE_PERIOD milli seconds
--]]
local function update()
    -- retrieve high level steering and throttle control outputs
    local steering = vehicle:get_control_output(CONTROL_OUTPUT_YAW)
    local throttle = vehicle:get_control_output(CONTROL_OUTPUT_THROTTLE)

    if (steering and throttle) then
        gcs:send_text(6, "steering: " .. tonumber(steering) .. ", throttle: " .. tonumber(throttle))
    end

    return update, UPDATE_PERIOD
end

gcs:send_text(6, "monitor_control_outputs.lua is running")
return update(), 3000

