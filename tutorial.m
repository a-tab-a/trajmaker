% Copyright Jan. 2017, Joseph E. Macon
%
% Permission is hereby granted, free of charge, to any person obtaining a copy 
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.

% This tutorial introduces the new user to the TrajMaker class and its related
% scripts. The class's members and interface are explained in detail, and
% several trajectory creation examples are given. Finally, several scripts
% for loading and plotting saved trajectory files are discussed. This tutorial
% also serves as an executable script.

% This tutorial is a valid script and may be executed if desired.

% The TrajMaker class is a tool that creates complex, realistic trajectories by
% enforcing nearly continuous changes in acceleration in three dimensions.

% The TrajMaker class contains eleven user-settable members:
%
%     positionNED_m_,
%     speed_mps_,
%     bearing_deg_,
%     pitch_deg_,
%     maxAcc_gs_,
%     maxJerk_gsps_,
%     nominalUpdateRate_s_,
%     outputFileName_,
%     thickUpdates_,
%     useNUE_Output_, and
%     outputPrecision_,

% a setter method for each member, a flexible constructor, and three maneuver
% methods:
%
%     ChangeDirection(...),
%     ChangeSpeed(...), and
%     PropagateToTime(...).

% TrajMaker objects are configured up-front via the constructor and setter
% methods, and maneuvers are added afterwards. Once a maneuver is added,
% object configuration is locked, and calling any setter method will trigger an
% error message.

% TrajMaker is a value class, and value class syntax must be used when calling
% methods to update an object's internal state, e.g.:
%
%     myTraj = myTraj.ChangeDirection(...);

% A default TrajMaker object may be created by not passing any arguments to the
% constructor:
%
%     myTraj = TrajMaker;
% or
%     myTraj = TrajMaker();

% The constructor may be called with up to eleven arguments, matching the order
% of the members given above. Each argument passed overwrites the default value
% for the corresponding member. For example,
%
%     myTraj = TrajMaker([100.0, 200.0, 1e3], 300.0);
%
% will use all default values, except for positionNED_m_ and speed_mps_.
%
% Alternatively, this code achieves the same result:
%
%     myTraj = TrajMaker;
%     myTraj = myTraj.SetPosition([100.0, 200.0, 1e3]);
%     myTraj = myTraj.SetSpeed(300.0);

% Members and setter methods:
%
% Each setter method performs sanitization checks on input arguments. If invalid
% input is detected, an error message will halt execution and explain why the
% input is invalid.
%
% The positionNED_m_ member contains the target's position in North-East-Down
% coordinates (units of meters) as a 1x3 matrix. The corresponding setter method
% is SetPosition(). The default value is [0.0, 0.0, 0.0].
%
% The speed_mps_ member holds the target's speed (units of meters per second) as
% a scalar numeric. The corresponding setter method is SetSpeed(). The default
% value is 200.0.
%
% The bearing_deg_ member holds the target's bearing, the azimuthal component of
% its orientation relative to North, (units of degrees) as a scalar numeric. The
% corresponding setter method is SetBearing(). The default value is 0.0.
%
% The pitch_deg_ member holds the target's pitch, the elevation component of its
% orientation relative to the horizon, (units of degrees) as a scalar numeric.
% The corresponding setter method is SetPitch(). The default value is 0.0.
%
% The maxAcc_gs_ member holds the target's maximum acceleration (units of g's)
% as a scalar numeric. The corresponding setter method is SetMaxAcceleration().
% If a maneuver is requested with an acceleration exceeding this value, a 
% warning message will be printed and the maneuver acceleration reduced to this
% value. The default value is 6.0.
%
% The maxJerk_gsps_ member holds the target's maximum jerk, the time derivative
% of acceleration, (units of g's per second) as a scalar numeric. The
% corresponding setter method is SetMaxJerk(). If a maneuver is requested with
% a jerk that exceeds this value, a warning message will be printed and the
% manuever jerk reduced to this value. The default value is 3.0.
%
% The nominalUpdateRate_s_ member holds the nominal time between trajectory data
% points (units of seconds) as a scalar numeric. The corresponding setter method
% is SetNominalUpdateRate(). For example, to request a 10 Hz update rate, pass
% 0.1 to the setter. The default value is 0.1. The user is cautioned against
% setting the update rate to be too long, as this may yield discontinuities in
% the acceleration inferred from output data created by aggressive maneuvers.
%
% The outputFileName_ member holds the absolute filepath to be used for data
% output, as a string (char array). The corresponding setter method is
% SetOutputFileName(). Unlike other setter methods, SetOutputFileName does not
% merely copy the parameter passed in to its member. Instead, SetOutputFileName
% expects a simple file name and automatically creates an absolute file path
% with a '.traj' extension. As maneuvers are added, data points are
% automatically added to the output file. Following object initialization, if a
% file exists whose file path matches this value, it will be overwritten. Output
% files are stored in a directory named "output", relative to the current
% working directory. This directory is created automatically if it does not
% exist. The default value for outputFileName_ is that generated by passing
% 'trajectory' to SetOutputFileName.
%
% The thickUpdates_ member determines whether data points written to file are
% allowed to skip periods of straight and level flight, as a scalar logical
% (true/false). The corresponding setter method is SetThickUpdates(). When set
% to true, updates will be written consistently about the nominal update rate;
% when set to false, updates will be suspended until straight and level flight
% ends. The default value is false.
%
% The useNUE_Output_ member determines whether data points written to file use
% NED (North-East-Down) or (North-Up-East) coordinates, as a scalar logical
% (true/false). The corresponding setter method is SetUseNUE_Output(). When set
% to true, updates will be written using NUE coordinates; when set to false,
% updates will be written using NED coordinates. The default value is false.
%
% The outputPrecision_ member controls the floating point precision of values
% written to file, as a scalar counting number. The corresponding setter method
% is SetOutputPrecision(). It is very important that trajectories stored as text
% files maintain sufficient precision to capture realistic acceleration. If the
% precision is too low, acceleration inferred from file values may create
% problems for applications that might ingest them, such as a realistic tracking
% processor. With this concern in mind, the minimum precision allowed for output
% file values is 5. No maximum precision limit is enforced.

% Manuever methods:
%
% The ChangeDirection() method changes target orientation while keeping speed
% constant, and the ChangeSpeed() method changes target speed while keeping
% orientation constant. The PropagateToTime() method maintains straight and
% level flight up until a certain time.
%
% Each maneuver method expects a time value as the first argument to determine
% when to execute the maneuver. An internal clock keeps track of the time
% required to execute each successive maneuver. If a time value passed to a
% maneuver method is behind the internal clock time, the maneuver time is
% fast-forwarded to the clock time and a warning message is printed. If a time
% value passed to a maneuver method is ahead of the internal clock time, the
% target trajectory is propagated along its current orientation up until the
% maneuver time, and then the maneuver is executed. Thus, if several maneuvers
% are desired in immediate succession, the same time value may be used for each
% one, and the time warning messages may be ignored.
%
% The full definition of ChangeDirection is:
%
%     ChangeDirection(...
%         startingTime_s, ...
%         finalBearing_deg, ...
%         finalPitch_deg, ...
%         acceleration_gs, ...
%         jerk_gsps,
%         varargin);
%
% where startingTime_s (units of seconds) is a scalar numeric indicating the
% time the maneuver should be executed, finalBearing_deg (units of degrees) is a
% scalar numeric indicating the desired final bearing, finalPitch_deg (units of
% degrees) is a scalar numeric indicating the desired final pitch, acceleration_gs
% (units of g's) is a scalar numeric indicating the desired acceleration
% throughout the maneuver, and jerk_gsps (units of g's per second) is a scalar
% numeric indicating the desired jerk throughout the maneuver. If the
% acceleration/jerk exceeds the maximum value established at initialization, a
% warning message will be printed and the value reduced to its maximum limit.
% If the final orientation is nearly the same as the target's current
% orientation, the maneuver may be aborted-- a warning message will be printed
% to indicate this. Acceleration is ramped up and down linearly as the maneuver
% begins and ends.
%
% If acceleration_gs and/or jerk_gsps are not passed to ChangeDirection, they
% will automatically be set to the object's maximum acceleration and jerk.
%
% The algorithm used by ChangeDirection moves the velocity vector from point to
% point along the great circle arc connecting the starting and ending points.
% While this creates clean, efficient maneuvers, they may not always achieve
% what is desired. For instance, given the starting orientation (0.0, 45.0) and
% the ending orientation (180.0, 45.0) a spiral/corkscrew might be expected.
% However, the great circle arc connecting these points travels over the north
% pole, which yields a loop-like trajectory. To accommodate spiraling, a string
% 'spiral' may be passed as a final parameter to ChangeDirection. When this
% optional parameter is detected, acceleration is restricted to the horizontal
% plane.
%
% Another nuance of ChangeDirection worth noting is the case of antipodal
% orientations-- that is, opposite orientations, such as east-west. Antipodal
% orientations are connected by an infinite number of great circle arcs. For
% these cases, a third point on the sphere must be selected to pick a single arc.
% While ChangeDirection handles antipodal points, the user may wish to constrain
% trajectory behavior more specifically. For example, suppose a turn from east
% to west is desired, but the turn must pass through north instead of south.
% There is no guarantee that the trajectory generated by ChangeDirection will
% satisfy this desire. However, a simple (recommended) workaround is to change
% orientation slightly to the north immediately before executing the turn. This
% keeps the algorithm from being forced to "resolve" the arc for antipodal
% orientations.
%
% ChangeDirection does not currently support changes in direction greater than
% 180 degrees.
%
% The full definition of ChangeSpeed() is:
%
%     ChangeSpeed(...
%         startingTime_s, ...
%         finalSpeed_mps, ...
%         acceleration_gs, ...
%         jerk_gsps);
%
% where startingTime_s (units of seconds) is a scalar numeric indicating the
% time the maneuver should be executed, finalSpeed_mps (units of meters per
% second) is a scalar numeric indicating the desired final speed, acceleration_gs
% (units of g's) is a scalar numeric indicating the desired acceleration
% throughout the maneuver, and jerk_gsps (units of g's per second) is a scalar
% numeric indicating the desired jerk throughout the maneuver. If the acceleration/
% jerk exceeds the maximum value established at initialization, a warning
% message will be printed and the value reduced to its maximum limit. If the
% final speed is nearly the same as the target's current speed, the maneuver may
% be aborted-- a warning message will be printed to indicate this. Acceleration
% is ramped up and down linearly as the maneuver begins and ends.
%
% If acceleration_gs and/or jerk_gsps are not passed to ChangeSpeed, they will
% automatically be set to the object's maximum acceleration and jerk.
%
% The full definition of PropagateToTime() is:
%
%     PropagateToTime(t_s);
%
% where t_s (units of seconds) is a scalar numeric indicating the time the
% trajectory should be propagated to, maintaining its current speed and
% orientation. If the time requested is less than or equal to the internal
% clock time, propagation is ignored and no warning or error message is printed.
% This method is called automatically by ChangeDirection() and ChangeSpeed() to
% advance the target to the requested maneuver time.

% The following examples create a handful of trajectories.

% Create a simple, outbound trajectory using mostly default values.
traj1 = TrajMaker;
traj1 = traj1.SetOutputFileName('Outbound');;

traj1 = traj1.ChangeSpeed(0.0, 400.0, 6.0, 2.0);

% Make a complicated trajectory.
% Ingress, dive, spiral around, and accelerate outbound.
traj2 = TrajMaker;
traj2 = traj2.SetOutputFileName('Evasive');
traj2 = traj2.SetPosition([100e3, 0.0, -6e3]);
traj2 = traj2.SetSpeed(200.0);
traj2 = traj2.SetBearing(180.0); % south-bound
traj2 = traj2.SetMaxAcceleration(8.0);
traj2 = traj2.SetMaxJerk(3.0);
traj2 = traj2.SetUseNUE_Output(true);
traj2 = traj2.SetNominalUpdateRate(0.2);
traj2 = traj2.SetThickUpdates(true);

% Use the same time to guarantee maneuvering as quickly as possible.
traj2 = traj2.ChangeDirection(5.0, 180.0, -60.0, 5.0, 3.0); % pitch down
traj2 = traj2.ChangeDirection(5.0, 0.0, -60.0, 5.0, 3.0, 'spiral'); % spiral
traj2 = traj2.ChangeSpeed(5.0, 400.0, 5.0, 3.0); % accelerate
traj2 = traj2.ChangeDirection(25.0, 0.0, 0.0, 5.0, 3.0); % level off

% Make an inbound S-turning trajectory.
traj3 = TrajMaker;
traj3 = traj3.SetOutputFileName('S-turns');
traj3 = traj3.SetPosition([100e3, 0.0, -6e3]);
traj3 = traj3.SetSpeed(300.0);
traj3 = traj3.SetBearing(180.0);

% Use the same time to maneuver as quickly as possible.
for i = 1:1:5
    traj3 = traj3.ChangeDirection(0.0, 225.0, 0.0, 6.0, 3.0);
    traj3 = traj3.ChangeDirection(0.0, 135.0, 0.0, 6.0, 3.0);
end

% Make a simple, easterly U-turn from south to north.
traj4 = TrajMaker;
traj4 = traj4.SetOutputFileName('SouthToNorth');
traj4 = traj4.SetPosition([100e3, 0.0, -6e3]);
traj4 = traj4.SetBearing(180.0);

% Offset the orientation slightly to the east immediately before maneuvering
% to keep ChangeDirection from "resolving" antipodal orientations. Leave desired
% acceleration and jerk unspecified to fall back on maximum acceleration and
% jerk.
traj4 = traj4.ChangeDirection(0.0, 179.0, 0.0);
traj4 = traj4.ChangeDirection(0.0, 0.0, 0.0);

% Once a trajectory has been created and saved to file, other scripts may be
% used to access and view the data.
%
% LoadTrajFile loads the contents of a trajectory file to a structure,
% PlotTrajFile creates a 3D position-velocity quiver plot of a trajectory, and
% ValidateTrajFile creates a handful of plots displaying data per dimension,
% e.g. north-east-down, including achieved acceleration.
%
% The full definition of LoadTrajFile is:
%
%    [data, isNED, filePath] = LoadTrajFile(filePath);
%
% where filePath is a string (char array) file path to a trajectory file, data
% is a struct whose field names match those found in the trajectory file, and
% isNED is a scalar logical (true/false) indicating whether the file contents
% use NED (true) or NUE (false). Note that the field names of data are different
% depending on these two cases. If LoadTrajFile is called without passing a
% string, a file selection dialog will prompt the user to select a trajectory
% file. In this case, the filePath returned is the path of the file actually
% opened. Otherwise, the filePath returned is the same as the filePath passed.
%
% The full definition of PlotTrajFile is:
%
%    PlotTrajFile(filePath);
%
% where filePath is a string (char array) file path to a trajectory file.
% PlotTrajFile creates a 3D position-velocity quiver plot of the trajectory in
% NUE coordinates. If PlotTrajFile is called without passing a string, a file
% selection dialog will prompt the user to select a trajectory file.
%
% The full definition of ValidateTrajFile is:
%
%     ValidateTrajFile(filePath);
%
% where filePath is a string (char array) file path to a trajectory file.
% ValidateTrajFile creates three figures useful for data analysis and ensuring
% achieved acceleration is in fact continuous, the driving goal of the TrajMaker
% class. The figures also show whether acceleration and jerk constraints have
% been honored. The first figure generated shows trajectory position in NED or
% NUE as three sub-plots, one for each dimension. The second figure generated
% shows trajectory velocity, and velocity as the time derivative of position, in
% NED or NUE as three sub-plots, one for each dimension. A fourth sub-plot shows
% the velocity magnitude. The third figure generated shows trajectory acceleration
% as the time derivative of velocity, and as the second time derivative of
% position, in NED or NUE as three sub-plots, one for each dimension. A fourth
% sub-plot shows the acceleration magnitude. If ValidateTrajFile is called
% without passing a string, a file selection dialog will prompt the user to
% select a trajectory file.

% Plot and validate the "Evasive" trajectory.
PlotTrajFile(traj2.outputFileName_);
ValidateTrajFile(traj2.outputFileName_);