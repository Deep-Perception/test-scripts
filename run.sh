#!/bin/bash


#Run model for 15 minutes

hailortcli run2 --measure-temp -t 900 set-net h10_yolox_l_leaky.hef --batch-size 8
