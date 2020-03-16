#property script_show_inputs

#include "TimePicker.mqh"

input CTimePicker::TIME InpTime = CTimePicker::T_09_00;

CTimePicker TimePicker;

void OnStart()
{
   datetime time = TimePicker.ReplaceTime(TimeCurrent(), InpTime);
   
   Alert("Time: ", time);
}
