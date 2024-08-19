#!/usr/bin/python
# -*- coding: UTF-8 -*-
#
# Usage calc_waypoints.py -l <lat,lon>
#
# This parses the iris_arducopter_runway.world file and for all
# models that aren't at origin the gps coordinates are printed.
# The supplied parameter is considered the origin point and
# equivalent to gazebo coordinates 0,0. This should match the
# -l parameter supplied to sim_vehicle.py.
#
#


import sys, getopt
from math import *
from lxml import etree


class WorldParser(object):
    current_model = ""
    calculate_coord = False

    def __init__(self, calculator):
        self.calculator = calculator

    def start(self, tag, attrib):
        if tag == "model":
            self.current_model = attrib['name']
        elif tag == "pose" and not self.current_model == "":
            self.calculate_coord = True

    def end(self, tag):
        if tag == "model":
            self.current_model = ""
        if tag == "pose":
            self.calculate_coord = False

    def data(self, data):
        if self.calculate_coord:
            (x, y) = parse_pose(data)
            if x == 0 and y == 0:
                return
            self.calculator(self.current_model, x, y)
    def close(self):
        return "closed!"

def parse_pose(pose_string):
    pose = pose_string.split(' ', 6)
    x = float(pose[0])
    y = float(pose[1])
    return (x, y)

def main(argv):
    origin_location=''
    try:
        opts, args = getopt.getopt(argv, "l:", ["location="])
    except getopt.GetoptError:
        print('calc_waypoints.py -l <lat,long> --location <lat,long>')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-l':
            origin_location = arg

    coordinates = origin_location.split(',', 2)
    lat = float(coordinates[0])
    lon = float(coordinates[1])

    print('Origin 0,0 specified as lat %.7f, lon %.7f' % (lat, lon))

    def calculate_coordinates(model, offset_x, offset_y):
        # print("Calculating offset %s (%f,%f) to %.7f,%.7f" % (model, offset_x, offset_y, lat, lon))
        # Translate NWU to NED
        x = offset_x
        y = -offset_y
        lat1 = radians(lat)
        lon1 = radians(lon)
        d = hypot(x, y)
        b = atan2(y, x)
        r = 6.37e6
        lat2_rad = asin(sin(lat1) * cos(d/r) + cos(lat1) * sin(d/r) * cos(b))
        lon2_rad = lon1 + atan2(sin(b) * sin(d/r) * cos(lat1), cos(d/r) - sin(lat1) * sin(lat2_rad))
        lat2 = degrees(lat2_rad)
        lon2 = degrees(lon2_rad)
        # print("Distance and bearing for %s is %.4f m, %0.3f°" % (model, d, degrees(b)))
        print("Coordinate for %s is lat %00.7f, lon %.7f" % (model, lat2, lon2))

    parser = etree.XMLParser(target=WorldParser(calculate_coordinates))
    etree.parse("worlds/iris_arducopter_runway.world", parser)


if __name__ == "__main__":
    main(sys.argv[1:])
