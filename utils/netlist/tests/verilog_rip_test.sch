v 20130925 2
C 40000 40000 0 0 0 title-B.sym
N 46800 46100 47600 46100 4
{
T 46900 46150 5 10 0 0 0 0 1
netname=q0
}
N 48800 46100 49500 46100 4
{
T 48900 46150 5 10 0 0 0 0 1
netname=q1
}
N 50700 46100 51500 46100 4
{
T 50800 46150 5 10 0 0 0 0 1
netname=q2
}
N 47100 46100 47100 47400 4
N 49100 46100 49100 47400 4
N 51100 46100 51100 47400 4
N 52700 46100 52800 46100 4
N 52800 46100 52800 47400 4
{
T 52750 46200 5 10 0 0 90 0 1
netname=q3
}
N 45600 46100 44600 46100 4
{
T 45500 46150 5 10 1 1 0 6 1
netname=clock
}
C 43700 46000 1 0 0 ipad-1.sym
{
T 43784 46221 5 10 0 1 0 0 1
device=IPAD
T 44400 46100 5 10 1 1 0 0 1
refdes=P2
}
C 47200 47400 1 90 0 opad-1.sym
{
T 46982 47702 5 10 0 1 90 0 1
device=OPAD
T 47100 47600 5 10 1 1 90 6 1
refdes=P3
}
C 49200 47400 1 90 0 opad-1.sym
{
T 48982 47702 5 10 0 1 90 0 1
device=OPAD
T 49100 47600 5 10 1 1 90 6 1
refdes=P4
}
C 51200 47400 1 90 0 opad-1.sym
{
T 50982 47702 5 10 0 1 90 0 1
device=OPAD
T 51100 47600 5 10 1 1 90 6 1
refdes=P5
}
C 52900 47400 1 90 0 opad-1.sym
{
T 52682 47702 5 10 0 1 90 0 1
device=OPAD
T 52800 47600 5 10 1 1 90 6 1
refdes=P6
}
T 53700 50600 8 10 1 0 0 0 1
module_name=RIPPLE_COUNT
C 43700 45400 1 0 0 ipad-1.sym
{
T 43784 45621 5 10 0 1 0 0 1
device=IPAD
T 44400 45500 5 10 1 1 0 0 1
refdes=P1
}
N 44600 45500 52100 45500 4
{
T 45100 45600 5 10 1 1 0 0 1
netname=reset
}
C 51500 45500 1 0 0 D_FF.sym
{
T 51800 47100 5 10 0 0 0 0 1
device=T_FF
T 51800 46900 5 10 1 1 0 0 1
refdes=U4
}
C 49500 45500 1 0 0 D_FF.sym
{
T 49800 47100 5 10 0 0 0 0 1
device=T_FF
T 49800 46900 5 10 1 1 0 0 1
refdes=U3
}
C 47600 45500 1 0 0 D_FF.sym
{
T 47900 47100 5 10 0 0 0 0 1
device=T_FF
T 47900 46900 5 10 1 1 0 0 1
refdes=U2
}
C 45600 45500 1 0 0 D_FF.sym
{
T 45900 47100 5 10 0 0 0 0 1
device=T_FF
T 45900 46900 5 10 1 1 0 0 1
refdes=U1
}