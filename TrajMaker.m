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

% TrajMaker creates complex, realistic trajectories by enforcing nearly
% continuous changes in acceleration in three dimensions.
classdef TrajMaker

properties (GetAccess = public, SetAccess = private)

    % These may be changed internally at initialization.
    % These may be changed internally after initialization.
    clockTime_s_;

    % These may be changed internally or externally at initialization.
    % These may be changed internally after initialization.
    positionNED_m_;
    speed_mps_;
    bearing_deg_; % azimuthal angle rel. to north
    pitch_deg_; % elevation angle rel. to horizon
    
    % These may be changed internally or externally at initialization.
    % These may not be changed after initialization.
    maxAcc_gs_;
    maxJerk_gsps_; % g's per second
    nominalUpdateRate_s_;
    outputFileName_;
    thickUpdates_;
    useNUE_Output_;
    outputPrecision_;
    
end % gettable properties

properties (GetAccess = private, SetAccess = private, Hidden = true)

    isInitialized_;

end % hidden properties

methods (Access = public)

    function obj = TrajMaker(varargin)
    
        % Set all members to default values to satisfy the zero argument
        % requirement.
        obj.clockTime_s_ = 0.;
        obj = obj.SetPosition([0., 0., 0.]);
        obj = obj.SetSpeed(200.);
        obj = obj.SetBearing(0.);
        obj = obj.SetPitch(0.);
        obj = obj.SetMaxAcceleration(6.);
        obj = obj.SetMaxJerk(3.);
        obj = obj.SetNominalUpdateRate(0.1);
        obj = obj.SetOutputFileName('trajectory');
        obj = obj.SetThickUpdates(false);
        obj = obj.SetUseNUE_Output(false);
        obj = obj.SetOutputPrecision(5);
        obj.isInitialized_ = false;

        if (nargin > 11)
            error('TrajMaker: Only 11 arguments may be accepted for construction.');
        end

        if (nargin > 0)
            obj = obj.SetPosition(varargin{1});
        end
        
        if (nargin > 1)
            obj = obj.SetSpeed(varargin{2});
        end
        
        if (nargin > 2)
            obj = obj.SetBearing(varargin{3});
        end
        
        if (nargin > 3)
            obj = obj.SetPitch(varargin{4});
        end
        
        if (nargin > 4)
            obj = obj.SetMaxAcceleration(varargin{5});
        end
        
        if (nargin > 5)
            obj = obj.SetMaxJerk(varargin{6});
        end
        
        if (nargin > 6)
            obj = obj.SetNominalUpdateRate(varargin{7});
        end
        
        if (nargin > 7)
            obj = obj.SetOutputFileName(varargin{8});
        end

        if (nargin > 8)
            obj = obj.SetThickUpdates(varargin{9});
        end

        if (nargin > 9)
            obj = obj.SetUseNUE_Output(varargin{10});
        end
        
        if (nargin > 10)
            obj = obj.SetOutputPrecision(varargin{11});
        end
        
    end % TrajMaker

end % public methods

methods (Static = true, Access = private)

    function [isValid, errMsg] = IsPositionInputValid(value)
        
        isValid = true;
        errMsg = '';
        
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isvector(value))
            isValid = false;
            errMsg = 'value must be a vector.';
            return;
        end

        if (length(value) ~= 3)
            isValid = false;
            errMsg = 'value must have 3 elements.';
            return;
        end
        
    end % IsPositionInputValid
    
    function [isValid, errMsg] = IsTimeInputValid(value)
    
        isValid = true;
        errMsg = '';
    
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end
        
        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end
        
        if (value < 0.)
            isValid = false;
            errMsg = 'value must be >= zero.';
            return;
        end
    
    end % IsTimeInputValid
    
    function [isValid, errMsg] = IsSpeedInputValid(value)
    
        isValid = true;
        errMsg = '';
        
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end

        if (value <= 0.)
            isValid = false;
            errMsg = 'value must be > zero.';
            return;
        end
    
    end % IsSpeedInputValid
    
    function [isValid, errMsg] = IsBearingInputValid(value)
        
        isValid = true;
        errMsg = '';
    
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end

        if (abs(value) > 360.)
            isValid = false;
            errMsg = 'value must be within [-360., 360.].';
            return;
        end

    end % IsBearingInputValid
    
    function [isValid, errMsg] = IsPitchInputValid(value)
    
        isValid = true;
        errMsg = '';
    
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end

        if (abs(value) > 90.)
            isValid = false;
            errMsg = 'value must be within [-90., 90.]';
            return;
        end
    
    end % IsPitchInputValid
    
    function [isValid, errMsg] = IsAccelerationInputValid(value)
    
        isValid = true;
        errMsg = '';
    
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end

        if (value <= 0.)
            isValid = false;
            errMsg = 'value must be > zero.';
            return;
        end
        
    end % IsAccelerationInputValid
    
    function [isValid, errMsg] = IsJerkInputValid(value)

        isValid = true;
        errMsg = '';
    
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end

        if (value <= 0.)
            isValid = false;
            errMsg = 'value must be > zero.';
            return;
        end
        
    end % IsJerkInputValid
    
    function [isValid, errMsg] = IsNominalUpdateRateInputValid(value)
    
        isValid = true;
        errMsg = '';
    
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end

        % Cap update rate at 100 Hz (10 ms).
        if (value < 0.01)
            isValid = false;
            errMsg = 'value must be >= 0.01.';
            return;
        end
        
    end % IsNominalUpdateRateInputValid
    
    function [isValid, errMsg] = IsFileNameInputValid(value)
    
        isValid = true;
        errMsg = '';
        
        if (~ischar(value))
            isValid = false;
            errMsg = 'value must be a char array.';
            return;
        end
        
        if (isempty(value))
            isValid = false;
            errMsg = 'value must not be empty.';
            return;
        end
    
    end % IsFileNameInputValid
    
    function [isValid, errMsg] = IsThickUpdatesInputValid(value)
        
        isValid = true;
        errMsg = '';
        
        if (~islogical(value))
            isValid = false;
            errMsg = 'value must be a logical.';
            return;
        end
        
        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end
        
    end % IsThickUpdatesInputValid
    
    function [isValid, errMsg] = IsUseNUE_OutputInputValid(value)
        
        isValid = true;
        errMsg = '';
        
        if (~islogical(value))
            isValid = false;
            errMsg = 'value must be a logical.';
            return;
        end
        
        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end
        
    end % IsUseNUE_OutputInputValid
    
    function [isValid, errMsg] = IsOutputPrecisionInputValid(value)
    
        isValid = true;
        errMsg = '';
        
        if (~isnumeric(value))
            isValid = false;
            errMsg = 'value must be a numeric.';
            return;
        end

        if (~isscalar(value))
            isValid = false;
            errMsg = 'value must be a scalar.';
            return;
        end
        
        if (value ~= floor(value))
            isValid = false;
            errMsg = 'value must be an integer.';
            return;
        end
        
        % Floor precision at 5 decimal places.
        if (value < 5)
            isValid = false;
            errMsg = 'value must be >= 5.';
            return;
        end
    
    end % IsOutputPrecisionInputValid

end % static, private methods

methods (Access = public)

    function value = GetPosition(obj)
        value = obj.positionNED_m_;
    end % GetPosition

    function obj = SetPosition(obj, positionNED_m)

        if (obj.isInitialized_)
            error('SetPosition: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsPositionInputValid(positionNED_m);
        if (~isValid)
            error('SetPosition: invalid value: %s', errMsg);
        end
        
        obj.positionNED_m_ = positionNED_m;
        
    end % SetPosition
    
    function value = GetSpeed(obj)
        value = obj.speed_mps_;
    end % GetSpeed
    
    function obj = SetSpeed(obj, speed_mps)
    
        if (obj.isInitialized_)
            error('SetSpeed: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsSpeedInputValid(speed_mps);
        if (~isValid)
            error('SetSpeed: invalid value: %s', errMsg);
        end
        
        obj.speed_mps_ = speed_mps;
       
    end % SetSpeed
    
    function value = GetBearing(obj)
        value = obj.bearing_deg_;
    end % GetBearing
    
    function obj = SetBearing(obj, bearing_deg)
    
        if (obj.isInitialized_)
            error('SetBearing: The object is already initialized. Aborting...');
        end
        
        [isValid, errMsg] = TrajMaker.IsBearingInputValid(bearing_deg);
        if (~isValid)
            error('SetBearing: invalid value: %s', errMsg);
        end
        
        obj.bearing_deg_ = bearing_deg;
        
    end % SetBearing
    
    function value = GetPitch(obj)
        value = obj.pitch_deg_;
    end % GetPitch
    
    function obj = SetPitch(obj, pitch_deg)
    
        if (obj.isInitialized_)
            error('SetPitch: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsPitchInputValid(pitch_deg);
        if (~isValid)
            error('SetPitch: invalid value: %s', errMsg);
        end
        
        obj.pitch_deg_ = pitch_deg;
        
    end % SetPitch
    
    function value = GetMaxAcceleration(obj)
        value = obj.maxAcc_gs_;
    end % GetMaxAcceleration
    
    function obj = SetMaxAcceleration(obj, maxAcc_gs)
    
        if (obj.isInitialized_)
            error('SetMaxAcceleration: The object is already initialized. Aborting...');
        end
        
        [isValid, errMsg] = TrajMaker.IsAccelerationInputValid(maxAcc_gs);
        if (~isValid)
            error('SetMaxAcceleration: invalid value: %s', errMsg);
        end
        
        obj.maxAcc_gs_ = maxAcc_gs;
        
    end % SetMaxAcceleration
    
    function value = GetMaxJerk(obj)
        value = obj.maxJerk_gsps_;
    end % GetMaxJerk
    
    function obj = SetMaxJerk(obj, maxJerk_gsps)

        if (obj.isInitialized_)
            error('SetMaxJerk: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsJerkInputValid(maxJerk_gsps);
        if (~isValid)
            error('SetMaxJerk: invalid value: %s', errMsg);
        end
        
        obj.maxJerk_gsps_ = maxJerk_gsps;
        
    end % SetMaxJerk
    
    function value = GetNominalUpdateRate(obj)
        value = obj.nominalUpdateRate_s_;
    end % GetNominalUpdateRate
    
    function obj = SetNominalUpdateRate(obj, nominalUpdateRate_s)

        if (obj.isInitialized_)
            error('SetNominalUpdateRate: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsNominalUpdateRateInputValid(nominalUpdateRate_s);
        if (~isValid)
            error('SetNominalUpdateRate: invalid value: %s', errMsg);
        end
        
        obj.nominalUpdateRate_s_ = nominalUpdateRate_s;
        
    end % SetNominalUpdateRate
    
    function value = GetOutputFileName(obj)
        value = obj.outputFileName_;
    end % GetOutputFileName
    
    function obj = SetOutputFileName(obj, fileName)

        if (obj.isInitialized_)
            error('SetOutputFileName: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsFileNameInputValid(fileName);
        if (~isValid)
            error('SetOutputFileName: invalid value: %s', errMsg);
        end
        
        % Make the output file name a complete, absolute file path.
        % If the output folder does not exist, make one.
        % Enforce a specific file extension.
        outputDir = fullfile(pwd, 'output');
        if ((exist(outputDir, 'dir') == 0) && ~mkdir(outputDir))
            error(['SetOutputFileName: Could not create output directory ', ...
                '''%s''.'], outputDir);
        end

        ext = '.traj';
        obj.outputFileName_ = [fullfile(outputDir, fileName), ext];
    
    end % SetOutputFileName
    
    function value = GetThickUpdates(obj)
        value = obj.thickUpdates_;
    end % GetThickUpdates
    
    function obj = SetThickUpdates(obj, thickUpdates)

        if (obj.isInitialized_)
            error('SetThickUpdates: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsThickUpdatesInputValid(thickUpdates);
        if (~isValid)
            error('SetThickUpdates: invalid value: %s', errMsg);
        end
        
        obj.thickUpdates_ = thickUpdates;
    
    end % SetThickUpdates
    
    function value = GetUseNUE_Output(obj)
        value = obj.useNUE_Output_;
    end % GetUseNUE_Output
    
    function obj = SetUseNUE_Output(obj, useNUE_Output)

        if (obj.isInitialized_)
            error('SetUseNUE_Output: The object is already initialized. Aborting...');
        end
    
        [isValid, errMsg] = TrajMaker.IsUseNUE_OutputInputValid(useNUE_Output);
        if (~isValid)
            error('SetUseNUE_Output: invalid value: %s', errMsg);
        end
        
        obj.useNUE_Output_ = useNUE_Output;
    
    end % SetUseNUE_Output
    
    function value = GetOutputPrecision(obj)
        value = obj.outputPrecision_;
    end % GetOutputPrecision
    
    function obj = SetOutputPrecision(obj, outputPrecision)
    
        if (obj.isInitialized_)
            error('SetOutputPrecision: The object is already initialized. Aborting...');
        end
        
        [isValid, errMsg] = TrajMaker.IsOutputPrecisionInputValid(outputPrecision);
        if (~isValid)
            error('SetOutputPrecision: invalid value: %s', errMsg);
        end
        
        obj.outputPrecision_ = outputPrecision;
    
    end % SetOutputPrecision
    
end % public methods

methods (Access = private)
    
    % If the object is uninitialized, verify that the output file can be opened,
    % and clear its contents if it exists.
    function obj = InitializeOutputFile(obj)

        % Return silently if the output file is already initialized.
        if (obj.isInitialized_)
            return;
        end
    
        % Add dependencies to path.
        addpath('dependencies');

        % Open the file, overwriting its contents if it already exists.        
        [fID, msg] = fopen(obj.outputFileName_, 'w');
        if (fID == -1)
            error(['InitializeOutputFile: The file ''%s'' cannot be opened for ', ...
                'writing. System error: ''%s''.'], obj.outputFileName_, msg);
        end
        
        % Write the file header.
        if (obj.useNUE_Output_)
            fprintf(fID, 'Time_s\t');
            fprintf(fID, 'PosN_m\t');
            fprintf(fID, 'PosU_m\t');
            fprintf(fID, 'PosE_m\t');
            fprintf(fID, 'VelN_mps\t');
            fprintf(fID, 'VelU_mps\t');
            fprintf(fID, 'VelE_mps');
        else
            fprintf(fID, 'Time_s\t');
            fprintf(fID, 'PosN_m\t');
            fprintf(fID, 'PosE_m\t');
            fprintf(fID, 'PosD_m\t');
            fprintf(fID, 'VelN_mps\t');
            fprintf(fID, 'VelE_mps\t');
            fprintf(fID, 'VelD_mps');
        end
        
        % Close the file here so WriteToFile can open it.
        fclose(fID);
        
        % Get velocity in NED.
        [velocityN_mps, velocityE_mps, velocityD_mps] = ...
            sph2NED_deg(obj.bearing_deg_, obj.pitch_deg_, obj.speed_mps_);
        
        % Write a single data point to file.
        obj = obj.WriteToFile(...
            0.,
            obj.positionNED_m_(1), ...
            obj.positionNED_m_(2), ...
            obj.positionNED_m_(3), ...
            velocityN_mps, ...
            velocityE_mps, ...
            velocityD_mps);
            
        obj.isInitialized_ = true;
        
    end % InitializeOutputFile
    
    function obj = WriteToFile(...
        obj, ...
        time_s, ...
        positionN_m, ...
        positionE_m, ...
        positionD_m, ...
        velocityN_mps, ...
        velocityE_mps, ...
        velocityD_mps)
        
        % Write data to file, appending.
        [fID, msg] = fopen(obj.outputFileName_, 'a');
        if (fID == -1)
            error(['WriteToFile: The file ''%s'' could not be opened for writing ', ...
                '(appending). System message: ''%s''.'], obj.outputFileName_, msg);
        end
        
        temp = ['%.', sprintf('%d', obj.outputPrecision_), 'f'];
        tempTabbed = [temp, '\t'];
        formatString = ['\n', repmat(tempTabbed, 1, 6), temp];
        
        for i = 1:1:length(time_s)

            if (obj.useNUE_Output_)
                fprintf( ...
                    fID,
                    formatString, ...
                    time_s(i), ...
                    positionN_m(i), ...
                    -positionD_m(i), ...
                    positionE_m(i), ...
                    velocityN_mps(i), ...
                    -velocityD_mps(i), ...
                    velocityE_mps(i));
            else
                fprintf( ...
                    fID,
                    formatString, ...
                    time_s(i), ...
                    positionN_m(i), ...
                    positionE_m(i), ...
                    positionD_m(i), ...
                    velocityN_mps(i), ...
                    velocityE_mps(i), ...
                    velocityD_mps(i));
            end
        end
            
        fclose(fID);
        
    end % WriteToFile

end % private methods

methods (Access = public)
    
    % Given two angles in spherical coordinates (azimuth and elevation relative to
    % local north), a starting point, a constant speed, maximum acceleration and
    % jerk, and a nominal update rate, compute the points along the trajectory, an
    % arc of a great circle, maintaining nearly continuous acceleration.    
    function obj = ChangeDirection(...
        obj, ...
        startingTime_s, ...
        finalBearing_deg, ...
        finalPitch_deg, ...
        acceleration_gs, ...
        jerk_gsps,
        varargin)
        
        % Add dependencies to path.
        addpath('dependencies');
        
        obj = obj.InitializeOutputFile();
        
        % Accommodate for some parameters being optional.
        if (exist('acceleration_gs', 'var') ~= 1)
            acceleration_gs = obj.maxAcc_gs_;
        end
        
        if (exist('jerk_gsps', 'var') ~= 1)
            jerk_gsps = obj.maxJerk_gsps_;
        end
        
        % Sanitization.
        [isValid, message] = TrajMaker.IsTimeInputValid(startingTime_s);
        if (~isValid)
            error('ChangeDirection: invalid starting time: %s', message);
        end
        
        if (startingTime_s < obj.clockTime_s_)
            warning(['ChangeDirection: starting time (%.3f s) is < internal clock time ', ...
                '(%.3f s). Advancing starting time to clock time.'], ...
                startingTime_s, obj.clockTime_s_);
            startingTime_s = obj.clockTime_s_;
        end
        
        [isValid, message] = TrajMaker.IsBearingInputValid(finalBearing_deg);
        if (~isValid)
            error('ChangeDirection: invalid final bearing: %s', message);
        end
        
        [isValid, message] = TrajMaker.IsPitchInputValid(finalPitch_deg);
        if (~isValid)
            error('ChangeDirection: invalid final pitch: %s', message);
        end
        
        [isValid, message] = TrajMaker.IsAccelerationInputValid(acceleration_gs);
        if (~isValid)
            error('ChangeDirection: invalid acceleration: %s', message);
        end
        
        if (acceleration_gs > obj.maxAcc_gs_)
            warning(['ChangeDirection: acceleration (%f g''s) is > max acceleration ', ...
                '(%f g''s). Capping acceleration to max acceleration.'], ...
                acceleration_gs, obj.maxAcc_gs_);
            acceleration_gs = obj.maxAcc_gs_;
        end
        
        [isValid, message] = TrajMaker.IsJerkInputValid(jerk_gsps);
        if (~isValid)
            error('ChangeDirection: invalid jerk: %s', message);
        end
        
        if (jerk_gsps > obj.maxJerk_gsps_)
            warning(['ChangeDirection: jerk (%f g''s/s) is > max jerk (%f g''s/s). ', ...
                'Capping jerk to max jerk.'], jerk_gsps, obj.maxJerk_gsps_);
            jerk_gsps = obj.maxJerk_gsps_;
        end
        
        % Check for a spiraling maneuver request.
        spiralingManeuver = false;
        if (length(varargin) > 0)
            if (ischar(varargin{1}) && strcmp(varargin{1}, 'spiral'))
                % Only allow spiraling for requests whose final pitch match the
                % current pitch.
                if (finalPitch_deg == obj.pitch_deg_)
                    spiralingManeuver = true;
                else
                    warning(['ChangeDirection: Spiraling cannot be honored ', ...
                        'because final pitch (%f deg) does not equal current ', ...
                        'pitch (%f deg). Ignoring spiral request...'], ...
                        finalPitch_deg, ...
                        obj.pitch_deg_);
                end
            else
                warning(['ChangeDirection: Invalid varargin input. Only ', ...
                    '''spiral'' is a valid input.']);
            end
        end

        % Az is relative to local north.
        az1_deg = obj.bearing_deg_;
        el1_deg = obj.pitch_deg_;

        az2_deg = finalBearing_deg;
        el2_deg = finalPitch_deg;
        
        if (spiralingManeuver)
            el1_deg = 0.;
            el2_deg = 0.;
        end

        % Advance the constant magnitude velocity vector from (az1, el1) to (az2, el2)
        % along the great circle arc connecting the two points. The acceleration must
        % ramp up as the maneuver begins, to maxAcc_gs, and down as the maneuver ends,
        % to zero gs.

        % For all spherical angle pairs that are not antipodal, let P be the unit vector
        % from the origin to (az1, el1) and Q be the unit vector from the origin to 
        % (az2, el2). Then, V = P x Q is the axis of the great circle containing P and 
        % Q. Let theta be the angle in the plane of this great circle, from P. Then,
        % U = V x P exists at theta = pi/2. Thus, the vectors P and U are orthogonal,
        % and a parametric expression gives the points W on the great circle of 
        % interest, from P: W = P*cos(theta) + U*sin(theta). The angle between P and Q
        % can be found readily from the dot product, giving the bounds for theta.

        % For antipodal spherical angle pairs, V = P x Q is zero and there are an
        % infinite number of great circles containing P and Q. For these pairs we
        % select a third angle (az3, el3) to define a unique great circle.

        deg2rad = pi / 180.;
        rad2deg = 180. / pi;

        [pN, pE, pD] = sph2NED_deg(az1_deg, el1_deg, 1.);
        [qN, qE, qD] = sph2NED_deg(az2_deg, el2_deg, 1.);

        p = [pN, pE, pD];
        q = [qN, qE, qD];

        dotPq = dot(p, q);
        anglePq_deg = acos(dotPq) * rad2deg;

        % These logicals are mutually exclusive.
        pointsAreAntipodal = false;
        pointsAreClose = false;

        if (anglePq_deg > 179.9)
            pointsAreAntipodal = true;
        elseif (anglePq_deg < 0.1)
            pointsAreClose = true;
        end

        if (pointsAreClose)
            % The change is insignificant.
            warning(['ChangeDirection: Starting angles (%f, %f deg) and ending angles ', ...
                '(%f, %f deg) are too close. Aborting...'], ...
                az1_deg, ...
                el1_deg, ...
                az2_deg, ...
                el2_deg);                
            return;
        elseif (pointsAreAntipodal)
            % Select a third point (az3, el3) to define a unique great circle.
            az3_deg = az1_deg + (az2_deg - az1_deg) / 2.;
            if (az3_deg < 0.)
                az3_deg = mod(az3_deg, -360.);
            else
                az3_deg = mod(az3_deg, 360.);
            end
            
            el3_deg = el1_deg + (el2_deg - el1_deg) / 2.;
            if (el3_deg < 0.)
                el3_deg = mod(el3_deg, -90.);
            else
                el3_deg = mod(el3_deg, 90.);
            end
            
            % The code that follows relies on pqAngle_deg. Changing q
            % to calculate a useful v and u shouldn't break anything.
            [qN, qE, qD] = sph2NED_deg(az3_deg, el3_deg, 1.);
            q = [qN, qE, qD];
        end
        
        % Now that we know the request will not be ignored, it is safe to
        % propagate.
        obj = obj.PropagateToTime(startingTime_s);

        % Normalize the result of the cross products to guarantee unit vectors.
        v = cross(p, q);
        magV = sqrt(v(1)^2 + v(2)^2 + v(3)^2);
        v = v ./ magV;

        u = cross(v, p);
        magU = sqrt(u(1)^2 + u(2)^2 + u(3)^2);
        u = u ./ magU;

        % We need to consider the possibilities concerning ramping acceleration up and
        % down. The most common maneuver is expected to be one whose coordinates differ
        % significantly in angle, allowing enough angular space for a ramp-up to the 
        % requested acceleration, maintain constant acceleration, and a ramp-down to zero
        % acceleration. However, if the coordinates are close, ramping up to the requested
        % acceleration may exceed the desired angle difference. If this is the case, the
        % first half of the maneuver may need to be a partial ramp-up, and the second 
        % half a partial ramp-down.

        % Assume circular radial acceleration along the great circle arc, given by 
        % vt^2 / r, where vt is the tangential velocity and r is the radius of the great
        % circle. Setting vt to a constant speed, acceleration is controlled by
        % adjusting r. For constant acceleration, r is also constant; for increasing
        % acceleration, r decreases; and for decreasing acceleration, r increases.
        % Assuming radial acceleration changes linearly, it can be shown that the
        % following formulae define the maneuver angularly within the great circle:

        % For constant acceleration,

        % theta = omega * t + theta0, 
        % where t = 0 when theta = theta0

        % For linearly changing acceleration,

        % theta = (1/2 * m / vt) * t^2 + omega0 * t + theta0,
        % where t = 0 when omega = omega0 and theta = theta0

        % theta is the angle within the great circle, in radians,
        % omega is the angular velocity, in radians per second, and
        % m is the slope of the radial acceleration, in meters per second^3

        % Furthermore, the change in angle for a given duration of linearly changing
        % acceleration is given by:

        % deltaTheta = (1/2 * m / vt) * (t2^2 - t1^2) + omega0 * (t2 - t1), in radians,
        % where omega = omega0 when t = t1.

        % For t1 = 0, this simplifies to:

        % deltaTheta = (1/2 * m / vt) * deltaT^2 + omega0 * deltaT

        m_mps3 = jerk_gsps * 9.8;
        vt_mps = obj.speed_mps_;
        rampDeltaT_s = acceleration_gs / jerk_gsps; % time to ramp-up/ramp-down
        
        if (spiralingManeuver)
            % Change vt_mps to be the horizontal velocity component.
            vt_mps = vt_mps * cos(obj.pitch_deg_ * deg2rad);
        end

        rampDeltaTheta_rad = (1/2 * m_mps3 / vt_mps) * rampDeltaT_s^2; % assume omega0 = zero
        rampDeltaTheta_deg = rampDeltaTheta_rad * rad2deg;

        achievedRampDeltaTheta_deg = rampDeltaTheta_deg;
        achievedMaxAcc_mps2 = acceleration_gs * 9.8;
        achievedRampDeltaT_s = rampDeltaT_s;

        if (anglePq_deg < 2 * rampDeltaTheta_deg)            
            % There is not enough angular space to ramp-up to the requested acceleration.
            % We must ramp-up and down to a lesser acceleration.
            achievedRampDeltaTheta_deg = anglePq_deg / 2.;
            
            % Solving for the time it takes to realize this new angle will inform the
            % smaller acceleration.
            achievedRampDeltaT_s = sqrt(2 * vt_mps * achievedRampDeltaTheta_deg * deg2rad / m_mps3);
            achievedMaxAcc_mps2 = m_mps3 * achievedRampDeltaT_s;
            
            % What will the angular velocity be at this point?
            % This value will be needed later to complete the ramp-down.
            r_m = vt_mps^2 / achievedMaxAcc_mps2; % radius of the great circle
            omega_radps = vt_mps / r_m; % angular velocity
        end

        % How many updates to cover each ramp?
        % Enforce a minimum value.
        % The +1 helps maintain the desired update rate.
        N_ramp = ceil(achievedRampDeltaT_s / obj.nominalUpdateRate_s_) + 1;
        if (N_ramp < 3)
            N_ramp = 3;
        end

        angleInBetween_deg = anglePq_deg - (2 * achievedRampDeltaTheta_deg);

        N_inBetween = 0;
        if (angleInBetween_deg > 0.)
            % Ramping up and down will not cover the entire arc; we will have constant
            % radial acceleration for the middle part. For how long?
            r_m = vt_mps^2 / (acceleration_gs * 9.8); % radius of the great circle
            omega_radps = vt_mps / r_m; % angular velocity
            timeInBetween_s = angleInBetween_deg * deg2rad / omega_radps;
            
            % The +2 here accounts for trimming to follow and helps keep the
            % update rate from dropping below the nominal rate.
            N_inBetween = ceil(timeInBetween_s / obj.nominalUpdateRate_s_) + 2;
            
            % Enforce a minimum value.
            % This will guarantee at least 1 "in between" point after trimming below.
            if (N_inBetween < 3)
                N_inBetween = 3;
            end
            
            firstInBetween_deg = achievedRampDeltaTheta_deg;
            lastInBetween_deg = anglePq_deg - achievedRampDeltaTheta_deg;
            thetaInBetween_deg = linspace(firstInBetween_deg, lastInBetween_deg, N_inBetween);
            
            firstTimeInBetween_s = achievedRampDeltaT_s;
            lastTimeInBetween_s = achievedRampDeltaT_s + timeInBetween_s;
            tInBetween_s = linspace(firstTimeInBetween_s, lastTimeInBetween_s, N_inBetween);
            
            % Currently,
            % The first "in between" point is the end of the ramp-up,
            % The last "in between" point is the beginning of the ramp-down.
            % They were needed to calculate the angles in between, but let's
            % remove them now because they are redundant.
            
            % This is why the minimum value of N_inBetween is 3 above.
            % This is also why 2 is added to the number of upates above.
            thetaInBetween_deg = thetaInBetween_deg(2:end-1);
            tInBetween_s = tInBetween_s(2:end-1);
            N_inBetween = N_inBetween - 2;

        end

        % Allocate memory.
        if (N_inBetween > 0)
            t_s = zeros(1, 2 * N_ramp + N_inBetween);
            theta_deg = zeros(1, 2 * N_ramp + N_inBetween);
        else
            % The last point of the ramp-up is the first point of the ramp-down.
            t_s = zeros(1, 2 * N_ramp - 1);
            theta_deg = zeros(1, 2 * N_ramp - 1);
        end

        % Stage 1: ramp-up.
        t_s(1:N_ramp) = linspace(0., achievedRampDeltaT_s, N_ramp);
        theta_deg(1:N_ramp) = (1/2 * m_mps3 / vt_mps) .* t_s(1:N_ramp) .^ 2; % omega0 = theta0 = zero
        theta_deg(1:N_ramp) = theta_deg(1:N_ramp) * rad2deg;

        % Stage 2: in between.
        if (N_inBetween > 0)
            t_s((N_ramp + 1):(N_ramp + N_inBetween)) = tInBetween_s;
            theta_deg((N_ramp + 1):(N_ramp + N_inBetween)) = thetaInBetween_deg;
        end

        % Stage 3: ramp-down.
        if (N_inBetween > 0)
            N_startOfRampDown = N_ramp + N_inBetween + 1;
            
            % This works because the points to the left and right of the last "in 
            % between" point are evenly spaced.
            dT_s = t_s(N_startOfRampDown - 1) - t_s(N_startOfRampDown - 2);
            startOfRampDown_s = t_s(N_startOfRampDown - 1) + dT_s;
        else
            % The last point of the ramp-up is the first point of the ramp-down.
            N_startOfRampDown = N_ramp;
            startOfRampDown_s = t_s(N_startOfRampDown);
        end

        endOfRampDown_s = startOfRampDown_s + achievedRampDeltaT_s;    
        t_s(N_startOfRampDown:end) = linspace(startOfRampDown_s, endOfRampDown_s, N_ramp);

        % For linearly changing acceleration,
        % theta = (1/2 * m / vt) * t^2 + omega0 * t + theta0,
        % where t = 0 when theta = theta0 and omega = omega0
           
        % Use the formula above for theta given linearly changing acceleration.
        m_mps3 = -m_mps3;
        omega0_radps = omega_radps;
        theta0_rad = (anglePq_deg - achievedRampDeltaTheta_deg) * deg2rad;

        % For simplicity, assume t = 0 when the ramp-down begins.
        % (This is the same as using the first part of the time series).
        theta_deg(N_startOfRampDown:end) = (1/2 * m_mps3 / vt_mps) .* t_s(1:N_ramp) .^ 2 + ...
            omega0_radps .* t_s(1:N_ramp) + theta0_rad;
            
        theta_deg(N_startOfRampDown:end) = theta_deg(N_startOfRampDown:end) .* rad2deg;

        % From earlier:
        % Thus, the vectors P and U are orthogonal, and a parametric expression gives
        % the points W on the great circle of interest, from P:
        % W = P*cos(theta) + U*sin(theta).

        sinTheta = sin(theta_deg .* deg2rad);
        cosTheta = cos(theta_deg .* deg2rad);

        velocityN_mps = vt_mps .* (p(1) .* cosTheta + u(1) .* sinTheta);
        velocityE_mps = vt_mps .* (p(2) .* cosTheta + u(2) .* sinTheta);
        velocityD_mps = vt_mps .* (p(3) .* cosTheta + u(3) .* sinTheta);

        % Add an extra velocity point at the end that copies the end value.
        % This allows position to be extrapolated from the final velocity
        % and for position and velocity vectors to share the same length.
        velocityN_mps(end + 1) = velocityN_mps(end);
        velocityE_mps(end + 1) = velocityE_mps(end);
        velocityD_mps(end + 1) = velocityD_mps(end);

        t_s(end + 1) = t_s(end) + obj.nominalUpdateRate_s_;
        
        if (spiralingManeuver)
            % velocityD_mps will be all zeros because vertical velocity has
            % been stripped out to generate the trajectory. Add the vertical
            % velocity component back now.
            velocityD_mps(1:end) = -obj.speed_mps_ * sin(obj.pitch_deg_ * deg2rad);
        end

        % Calculate position from starting point and velocity.
        positionN_m = zeros(1, length(velocityN_mps));
        positionE_m = zeros(1, length(velocityE_mps));
        positionD_m = zeros(1, length(velocityD_mps));

        positionN_m(1) = obj.positionNED_m_(1);
        positionE_m(1) = obj.positionNED_m_(2);
        positionD_m(1) = obj.positionNED_m_(3);

        dT_s = diff(t_s);

        for i = 1:1:length(dT_s)
            positionN_m(i + 1) = positionN_m(i) + velocityN_mps(i) * dT_s(i);
            positionE_m(i + 1) = positionE_m(i) + velocityE_mps(i) * dT_s(i);
            positionD_m(i + 1) = positionD_m(i) + velocityD_mps(i) * dT_s(i);
        end
        
        % Write data to file.
        % Assume the current state has already been written to file.
        % Therefore, skip the first data point.
        
        % For reasons unknown, passing the right-hand side of what follows 
        % directly to the WriteToFile method causes problems in Octave. This
        % workaround seems to appease it.
        time_s = obj.clockTime_s_ + t_s(2:end);
        positionN_m = positionN_m(2:end);
        positionE_m = positionE_m(2:end);
        positionD_m = positionD_m(2:end);
        velocityN_mps = velocityN_mps(2:end);
        velocityE_mps = velocityE_mps(2:end);
        velocityD_mps = velocityD_mps(2:end);
        
        obj = obj.WriteToFile(...,
            time_s, ...
            positionN_m, ...
            positionE_m, ...
            positionD_m, ...
            velocityN_mps, ...
            velocityE_mps, ...
            velocityD_mps);
        
        obj.clockTime_s_ = obj.clockTime_s_ + t_s(end);
        obj.positionNED_m_ = [positionN_m(end), positionE_m(end), positionD_m(end)];
        obj.bearing_deg_ = az2_deg;
        
        if (~spiralingManeuver)
            % If this is a spiraling maneuver, el2_deg will have been set to
            % zero even if this is not the desired final pitch. Do not capture
            % this expediency.
            obj.pitch_deg_ = el2_deg;
        end
        
    end % ChangeDirection
    
    % Change speed while maintaining a constant course and nearly continuous
    % acceleration.
    function obj = ChangeSpeed(...
        obj, ...
        startingTime_s, ...
        finalSpeed_mps, ...
        acceleration_gs, ...
        jerk_gsps)
        
        % Add dependencies to path.
        addpath('dependencies');
        
        obj = obj.InitializeOutputFile();
        
        % Accommodate for some parameters being optional.
        if (exist('acceleration_gs', 'var') ~= 1)
            acceleration_gs = obj.maxAcc_gs_;
        end
        
        if (exist('jerk_gsps', 'var') ~= 1)
            jerk_gsps = obj.maxJerk_gsps_;
        end
        
        % Sanitization.
        [isValid, message] = TrajMaker.IsTimeInputValid(startingTime_s);
        if (~isValid)
            error('ChangeSpeed: invalid starting time: %s', message);
        end
        
        if (startingTime_s < obj.clockTime_s_)
            warning(['ChangeSpeed: starting time (%.3f s) is < internal clock time (%.3f s). ', ...
                'Advancing starting time to clock time.'], startingTime_s, ...
                obj.clockTime_s_);
            startingTime_s = obj.clockTime_s_;
        end
        
        [isValid, errMsg] = TrajMaker.IsSpeedInputValid(finalSpeed_mps);
        if (~isValid)
            error('ChangeSpeed: invalid final speed: %s', errMsg);
        end
        
        [isValid, message] = TrajMaker.IsAccelerationInputValid(acceleration_gs);
        if (~isValid)
            error('ChangeSpeed: invalid acceleration: %s', message);
        end
        
        if (acceleration_gs > obj.maxAcc_gs_)
            warning(['ChangeSpeed: acceleration (%f g''s) is > max acceleration ', ...
                '(%f g''s). Capping acceleration to max acceleration.'], ...
                acceleration_gs, obj.maxAcc_gs_);
            acceleration_gs = obj.maxAcc_gs_;
        end
        
        [isValid, message] = TrajMaker.IsJerkInputValid(jerk_gsps);
        if (~isValid)
            error('ChangeSpeed: invalid jerk: %s', message);
        end
        
        if (jerk_gsps > obj.maxJerk_gsps_)
            warning(['ChangeSpeed: jerk (%f g''s/s) is > max jerk (%f g''s/s). ', ...
                'Capping jerk to max jerk.'], jerk_gsps, obj.maxJerk_gsps_);
            jerk_gsps = obj.maxJerk_gsps_;
        end
        
        deltaSpeed_mps = finalSpeed_mps - obj.speed_mps_;
        magDeltaSpeed_mps = abs(deltaSpeed_mps);
        
        % Do not bother with trivial speed changes.
        if (magDeltaSpeed_mps < 0.1)
            warning(['ChangeSpeed: Starting speed (%f mps) and ending speed (%f mps) ', ...
                'are too close. Aborting...'],
                finalSpeed_mps, ...
                obj.speed_mps_);
                
            return;
        end
        
        % Now that we know the request will not be ignored, it is safe to
        % propagate.
        obj = obj.PropagateToTime(startingTime_s);
        
        % Until near the end of this method, simplify calculations by assuming
        % that the acceleration is positive. Then, near the end, change the sign
        % of the calculated speed if the acceleration is negative.
        
        % We need to consider the possibilities concerning ramping acceleration up and
        % down. The most common speed delta is expected to be large enough to allow
        % acceleration to ramp-up to the requested acceleration, maintain constant 
        % acceleration, and ramp-down to zero acceleration. However, if the delta is 
        % small, ramping up to the requested acceleration may exceed the desired speed 
        % delta. If this is the case, the first half of the speed adjustment may need
        % to be a partial ramp-up, and the second half a partial ramp-down.
        
        % For constant acceleration,
        % v(t) = a * t + v0,
        % where v0 is the speed when t = t0.
        
        % For linearly changing acceleration,
        % v(t) = m / 2 * t^2 + b * t + v0,
        % where v0 is the speed when t = t0, m is the slope of the acceleration,
        % and b is the y-intercept of the acceleration.
        
        % The change in speed for a given duration of linearly changing
        % acceleration is given by:

        % deltaSpeed = (m / 2) * (t2^2 - t1^2) + b * (t2 - t1), in mps,

        % For t1 = 0, this simplifies to:

        % deltaSpeed = m / 2 * deltaT^2 + b * deltaT
        
        m_mps3 = jerk_gsps * 9.8;
        v_mps = obj.speed_mps_;
        rampDeltaT_s = acceleration_gs / jerk_gsps; % time to ramp-up/ramp-down

        rampDeltaSpeed_mps = (m_mps3 / 2) * rampDeltaT_s^2; % b = 0

        achievedMaxAcc_mps2 = acceleration_gs * 9.8;
        achievedRampDeltaSpeed_mps = rampDeltaSpeed_mps;
        achievedRampDeltaT_s = rampDeltaT_s;
        
        if (magDeltaSpeed_mps < 2 * rampDeltaSpeed_mps)            
            % There is not enough velocity space to ramp-up to the requested acceleration.
            % We must ramp-up and down to a lesser acceleration.
            achievedRampDeltaSpeed_mps = magDeltaSpeed_mps / 2.;
            
            % Solving for the time it takes to realize this new speed will inform the
            % smaller acceleration.
            achievedRampDeltaT_s = sqrt(2 / m_mps3 * achievedRampDeltaSpeed_mps);
            achievedMaxAcc_mps2 = m_mps3 * achievedRampDeltaT_s;
        end
        
        % How many updates to cover each ramp?
        % Enforce a minimum value.
        % The +1 helps to maintain the nominal update rate.
        N_ramp = round(achievedRampDeltaT_s / obj.nominalUpdateRate_s_) + 1;
        if (N_ramp < 3)
            N_ramp = 3;
        end

        deltaSpeedInBetween_mps = magDeltaSpeed_mps - (2 * achievedRampDeltaSpeed_mps);
        
        N_inBetween = 0;
        if (deltaSpeedInBetween_mps > 0.)            
            % Ramping up and down will not cover the entire speed delta; we will 
            % have constant acceleration for the middle part. For how long?
            timeInBetween_s = deltaSpeedInBetween_mps / achievedMaxAcc_mps2;
            
            % The +2 here accounts for trimming to follow and helps keep the
            % update rate from dropping below the nominal rate.
            N_inBetween = ceil(timeInBetween_s / obj.nominalUpdateRate_s_) + 2;
            
            % Enforce a minimum value.
            % This will guarantee at least 1 "in between" point after trimming below.
            if (N_inBetween < 3)
                N_inBetween = 3;
            end
            
            firstInBetween_mps = achievedRampDeltaSpeed_mps;
            lastInBetween_mps = magDeltaSpeed_mps - achievedRampDeltaSpeed_mps;
            speedInBetween_mps = linspace(firstInBetween_mps, lastInBetween_mps, N_inBetween);
            
            firstTimeInBetween_s = achievedRampDeltaT_s;
            lastTimeInBetween_s = achievedRampDeltaT_s + timeInBetween_s;
            tInBetween_s = linspace(firstTimeInBetween_s, lastTimeInBetween_s, N_inBetween);
            
            % Currently,
            % The first "in between" point is the end of the ramp-up, and
            % the last "in between" point is the beginning of the ramp-down.
            % They were needed to calculate the speeds in between, but let's
            % remove them now because they are redundant.
            
            % This is why the minimum value of N_inBetween is 3 above.
            speedInBetween_mps = speedInBetween_mps(2:end-1);
            tInBetween_s = tInBetween_s(2:end-1);
            N_inBetween = N_inBetween - 2;

        end

        % Allocate memory.
        if (N_inBetween > 0)
            t_s = zeros(1, 2 * N_ramp + N_inBetween);
            speed_mps = zeros(1, 2 * N_ramp + N_inBetween);
        else
            % The last point of the ramp-up is the first point of the ramp-down.
            t_s = zeros(1, 2 * N_ramp - 1);
            speed_mps = zeros(1, 2 * N_ramp - 1);
        end

        % Stage 1: ramp-up.
        t_s(1:N_ramp) = linspace(0., achievedRampDeltaT_s, N_ramp);
        speed_mps(1:N_ramp) = (m_mps3 / 2) .* t_s(1:N_ramp) .^ 2; % b = 0

        % Stage 2: in between.
        if (N_inBetween > 0)
            t_s((N_ramp + 1):(N_ramp + N_inBetween)) = tInBetween_s;
            speed_mps((N_ramp + 1):(N_ramp + N_inBetween)) = speedInBetween_mps;
        end

        % Stage 3: ramp-down.
        if (N_inBetween > 0)
            N_startOfRampDown = N_ramp + N_inBetween + 1;
            
            % This works because the points to the left and right of the last "in 
            % between" point are evenly spaced.
            dT_s = t_s(N_startOfRampDown - 1) - t_s(N_startOfRampDown - 2);
            startOfRampDown_s = t_s(N_startOfRampDown - 1) + dT_s;
        else
            % The last point of the ramp-up is the first point of the ramp-down.
            N_startOfRampDown = N_ramp;
            startOfRampDown_s = t_s(N_startOfRampDown);
        end
        
        endOfRampDown_s = startOfRampDown_s + achievedRampDeltaT_s;    
        t_s(N_startOfRampDown:end) = linspace(startOfRampDown_s, endOfRampDown_s, N_ramp);

        % For linearly changing acceleration,
        % v(t) = m / 2 * t^2 + b * t + v0,
        % where v0 is the speed when t = t0, m is the slope of the acceleration,
        % and b is the y-intercept of the acceleration.
           
        % Use the formula above for speed given linearly changing acceleration.
        m_mps3 = -m_mps3;
        v0_mps = magDeltaSpeed_mps - achievedRampDeltaSpeed_mps;

        % For simplicity, assume t = 0 when the ramp-down begins.
        % (This is the same as using the first part of the time series).
        b_mps2 = achievedMaxAcc_mps2;
        
        speed_mps(N_startOfRampDown:end) = (m_mps3 / 2) .* t_s(1:N_ramp) .^ 2 + ...
            b_mps2 .* t_s(1:N_ramp) + v0_mps;
        
        % Thus far, calculations have been simplified by assuming that the
        % acceleration is positive. If acceleration is negative, change the sign
        % of speed_mps.
        speed_mps = speed_mps .* sign(deltaSpeed_mps);
        
        % We have also assumed that the starting speed is zero. Add the true 
        % starting speed.
        speed_mps = speed_mps + obj.speed_mps_;
        
        % Now translate the speed into velocity.
        % Calculate the unit vector for velocity in NED.
        [pN, pE, pD] = sph2NED_deg(obj.bearing_deg_, obj.pitch_deg_, 1.);
        
        velocityN_mps = speed_mps .* pN;
        velocityE_mps = speed_mps .* pE;
        velocityD_mps = speed_mps .* pD;
        
        % Add an extra velocity point at the end that copies the end value.
        % This allows position to be extrapolated from the final velocity
        % and for position and velocity vectors to share the same length.
        velocityN_mps(end + 1) = velocityN_mps(end);
        velocityE_mps(end + 1) = velocityE_mps(end);
        velocityD_mps(end + 1) = velocityD_mps(end);

        t_s(end + 1) = t_s(end) + obj.nominalUpdateRate_s_;
        
        % Calculate position from starting point and velocity.
        positionN_m = zeros(1, length(velocityN_mps));
        positionE_m = zeros(1, length(velocityE_mps));
        positionD_m = zeros(1, length(velocityD_mps));

        positionN_m(1) = obj.positionNED_m_(1);
        positionE_m(1) = obj.positionNED_m_(2);
        positionD_m(1) = obj.positionNED_m_(3);

        dT_s = diff(t_s);

        for i = 1:1:length(dT_s)
            positionN_m(i + 1) = positionN_m(i) + velocityN_mps(i) * dT_s(i);
            positionE_m(i + 1) = positionE_m(i) + velocityE_mps(i) * dT_s(i);
            positionD_m(i + 1) = positionD_m(i) + velocityD_mps(i) * dT_s(i);
        end
        
        % Write data to file.
        % Assume the current state has already been written to file.
        % Therefore, skip the first data point.
        
        % For reasons unknown, passing the right-hand side of what follows 
        % directly to the WriteToFile method causes problems in Octave. This
        % workaround seems to appease it.
        time_s = obj.clockTime_s_ + t_s(2:end);
        positionN_m = positionN_m(2:end);
        positionE_m = positionE_m(2:end);
        positionD_m = positionD_m(2:end);
        velocityN_mps = velocityN_mps(2:end);
        velocityE_mps = velocityE_mps(2:end);
        velocityD_mps = velocityD_mps(2:end);
        
        obj = obj.WriteToFile(...,
            time_s, ...
            positionN_m, ...
            positionE_m, ...
            positionD_m, ...
            velocityN_mps, ...
            velocityE_mps, ...
            velocityD_mps);
        
        obj.clockTime_s_ = obj.clockTime_s_ + t_s(end);
        obj.positionNED_m_ = [positionN_m(end), positionE_m(end), positionD_m(end)];
        obj.speed_mps_ = finalSpeed_mps;
        
    end % ChangeSpeed
    
    % Add data point(s) maintaining staight and level flight.
    function obj = PropagateToTime(obj, t_s)
    
        % Add dependencies to path.
        addpath('dependencies');
        
        obj = obj.InitializeOutputFile();
        
        % Sanitization.
        [isValid, message] = TrajMaker.IsTimeInputValid(t_s);
        if (~isValid)
            error('PropagateToTime: invalid time: %s', message);
        end
        
        if (t_s <= obj.clockTime_s_)
            % Do not allow backwards propagation.
            return;
        end
        
        % Get velocity in NED.
        [velocityN_mps, velocityE_mps, velocityD_mps] = ...
            sph2NED_deg(obj.bearing_deg_, obj.pitch_deg_, obj.speed_mps_);
        
        dT_s = t_s - obj.clockTime_s_;
        time_s = dT_s;
        
        if (obj.thickUpdates_)
            % The +1 here accounts for trimming below and helps maintain the
            % desired update rate.
            N_updates = ceil(dT_s / obj.nominalUpdateRate_s_) + 1;
            
            % Enforce a minimum number of 2 updates.
            % This is set to 3 to allow trimming by 1 in a moment.
            if (N_updates < 3)
                N_updates = 3;
            end
            
            time_s = linspace(0., dT_s, N_updates);
            
            % Assume the current state has been written to file, so remove
            % the first data point.
            time_s = time_s(2:end);
            N_updates = N_updates - 1;
            
            velocityN_mps = repmat(velocityN_mps, 1, N_updates);
            velocityE_mps = repmat(velocityE_mps, 1, N_updates);
            velocityD_mps = repmat(velocityD_mps, 1, N_updates);
        end
        
        positionN_m = obj.positionNED_m_(1) + time_s .* velocityN_mps;
        positionE_m = obj.positionNED_m_(2) + time_s .* velocityE_mps;
        positionD_m = obj.positionNED_m_(3) + time_s .* velocityD_mps;
        
        % Write data to file.
        obj = obj.WriteToFile(...,
            obj.clockTime_s_ + time_s, ...
            positionN_m, ...
            positionE_m, ...
            positionD_m, ...
            velocityN_mps, ...
            velocityE_mps, ...
            velocityD_mps);
        
        obj.clockTime_s_ = t_s;
        obj.positionNED_m_ = [positionN_m(end), positionE_m(end), positionD_m(end)];
    
    end % PropagateToTime
    
end % public methods

end % TrajMaker