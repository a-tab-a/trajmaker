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
            errMsg = 'value must be within [-90., 90.].';
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

    % Select a third point (az3, el3) to define a unique great circle.
    function [az3_deg, el3_deg] = GetIntermediateAntipodalAngles(...
        az1_deg, el1_deg, az2_deg, el2_deg);

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

    end % GetIntermediateAntipodalAngles

    % Determine how long a ChangeSpeed maneuver would take.
    function [tNet_s, tRamp_s, tInBetween_s] = TimeRequiredToChangeSpeed(...
        beginSpeed_mps, ...
        finalSpeed_mps, ...
        acceleration_gs, ...
        jerk_gsps)

        deltaSpeed_mps = finalSpeed_mps - beginSpeed_mps;
        magDeltaSpeed_mps = abs(deltaSpeed_mps);

        m_mps3 = jerk_gsps * 9.8;
        rampDeltaT_s = acceleration_gs / jerk_gsps; % time to ramp-up/ramp-down

        rampDeltaSpeed_mps = (m_mps3 / 2) * rampDeltaT_s^2;

        achievedMaxAcc_mps2 = acceleration_gs * 9.8;
        achievedRampDeltaSpeed_mps = rampDeltaSpeed_mps;
        achievedRampDeltaT_s = rampDeltaT_s;

        if (magDeltaSpeed_mps < (2 * rampDeltaSpeed_mps))
            % There is not enough velocity space to ramp-up to the requested acceleration.
            % We must ramp-up and down to a lesser acceleration.
            achievedRampDeltaSpeed_mps = magDeltaSpeed_mps / 2.;

            % Solving for the time it takes to realize this new speed will inform the
            % smaller acceleration.
            achievedRampDeltaT_s = sqrt(2 / m_mps3 * achievedRampDeltaSpeed_mps);
            achievedMaxAcc_mps2 = m_mps3 * achievedRampDeltaT_s;
        end

        timeInBetween_s = 0.;
        deltaSpeedInBetween_mps = magDeltaSpeed_mps - (2 * achievedRampDeltaSpeed_mps);

        if (deltaSpeedInBetween_mps > 0.)
            % Ramping up and down will not cover the entire speed delta; we will
            % have constant acceleration for the middle part. For how long?
            timeInBetween_s = deltaSpeedInBetween_mps / achievedMaxAcc_mps2;
        end

        tRamp_s = achievedRampDeltaT_s;
        tInBetween_s = timeInBetween_s;
        tNet_s = (2 * achievedRampDeltaT_s) + timeInBetween_s;

     end % TimeRequiredToChangeSpeed

end % static, private methods

methods (Access = public)

    function value = GetClockTime(obj)
        value = obj.clockTime_s_;
    end % GetClockTime

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

     % Process optional input for ChangeDirection and ChangeDirectionAndSpeed.
    function options = ProcessVarargin(obj, functionName, varargin)

        % Initialize the struct.
        options.requestSpiral = false;

        counter = 1;
        numVarargin = length(varargin);

        while (counter <= numVarargin)

            allStringParametersFilled = options.requestSpiral && ...
                isfield(options, 'connectingAz_deg') && ...
                isfield(options, 'connectingEl_deg');

            % If we have maxed out the optional string parameters, we should
            % already be done due to the "strings come last" requirement.
            if (allStringParametersFilled)
                error('%s: invalid parameter(s) following string input.', functionName);
            end

            anyStringParametersFilled = options.requestSpiral || ...
                isfield(options, 'connectingAz_deg') || ...
                isfield(options, 'connectingEl_deg');

            if (isnumeric(varargin{counter}))
                if (anyStringParametersFilled)
                    error('%s: invalid optional input parameter (#%d) -- numerics must preceed strings.', ...
                        functionName, counter);
                else
                    if (~isfield(options, 'acceleration_gs'))
                        options.acceleration_gs = varargin{counter};
                    elseif (~isfield(options, 'jerk_gsps'))
                        options.jerk_gsps = varargin{counter};
                    else
                        error('%s: invalid optional input parameter (#%d) -- numeric input exhausted.', ...
                            functionName, counter);
                    end
                end
            elseif (ischar(varargin{counter}))
                if (strcmp(varargin{counter}, 'spiral'))
                    if (~options.requestSpiral)
                        options.requestSpiral = true;
                    else
                        error('%s: invalid optional input parameter (#%d) -- redundant string: ''%s''.', ...
                            functionName, counter, varargin{counter});
                    end
                elseif (strcmp(varargin{counter}, 'connect'))
                    if (~isfield(options, 'connectingAz_deg') && ...
                        ~isfield(options, 'connectingEl_deg'))

                        % A two-element numeric array of valid angles must follow.
                        if (counter >= numVarargin)
                            error('%s: invalid optional input parameter (#%d) -- missing pair parameter following ''connect''.', ...
                                functionName, counter);
                        end

                        counter = counter + 1;

                        if (~isnumeric(varargin{counter}))
                            error('%s: invalid optional input parameter (#%d) -- not numeric following ''connect''.', ...
                                functionName, counter);
                        end

                        if (length(varargin{counter}) ~= 2)
                            error('%s: invalid optional input parameter (#%d) -- must have length of 2.', ...
                                functionName, counter);
                        end

                        angles = varargin{counter};

                        [isValid, message] = TrajMaker.IsBearingInputValid(angles(1));
                        if (~isValid)
                            error('%s: invalid optional input parameter (#%d) -- invalid bearing angle: %s', ...
                                functionName, counter, message);
                        end

                        [isValid, message] = TrajMaker.IsPitchInputValid(angles(2));
                        if (~isValid)
                            error('%s: invalid optional input parameter (#%d) -- invalid pitch angle: %s', ...
                                functionName, counter, message);
                        end

                        options.connectingAz_deg = angles(1);
                        options.connectingEl_deg = angles(2);

                    else
                        error('%s: invalid optional input parameter (#%d) -- redundant string: ''%s''.', ...
                            functionName, counter, varargin{counter});
                    end
                else
                    error('%s: invalid optional input parameter (#%d) -- unrecognized string: ''%s''.', ...
                        functionName, counter, varargin{counter});
                end
            else
                error('%s: invalid optional input parameter (#%d) -- not numeric or string.', ...
                    functionName, counter);
            end

            counter = counter + 1;
        end

        % If optional parameters were not found, use existing values.
        if (~isfield(options, 'acceleration_gs'))
            options.acceleration_gs = obj.maxAcc_gs_;
        end

        if (~isfield(options, 'jerk_gsps'))
            options.jerk_gsps = obj.maxJerk_gsps_;
        end

    end % ProcessVarargin

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
        varargin)

        % Add dependencies to path.
        addpath('dependencies');

        obj = obj.InitializeOutputFile();

        % Process optional input.
        options = ProcessVarargin(obj, 'ChangeDirection', varargin{:});

        acceleration_gs = options.acceleration_gs;
        jerk_gsps = options.jerk_gsps;
        requestSpiral = options.requestSpiral;

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
        if (requestSpiral)
            % Only allow spiraling for requests whose final pitch matches the
            % current pitch.
            if (finalPitch_deg == obj.pitch_deg_)
                spiralingManeuver = true;
            else
                error(['ChangeDirection: Spiraling cannot be honored ', ...
                    'because final pitch (%f deg) does not equal current ', ...
                    'pitch (%f deg).'], ...
                    finalPitch_deg, ...
                    obj.pitch_deg_);
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

        threshold_deg = 0.1;
        [pointsAreClose, pointsAreAntipodal, p, q, anglePq_deg] = ...
            getAngleInfo(az1_deg, el1_deg, az2_deg, el2_deg, threshold_deg);

        haveConnectingAngles = isfield(options, 'connectingAz_deg') && ...
            isfield(options, 'connectingEl_deg');

        if (haveConnectingAngles && ~pointsAreAntipodal)
            warning(['ChangeDirection: Connecting angles detected, but the angles ', ...
                '(%f, %f) and (%f, %f) are not antipodal. Ignoring...'], ...
                az1_deg, ...
                el1_deg, ...
                az2_deg, ...
                el2_deg);
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
            % If valid connecting angles have been defined, use them. Otherwise,
            % fall back to a generic method.
            if (haveConnectingAngles)
                az3_deg = options.connectingAz_deg;
                el3_deg = options.connectingEl_deg;

                if (spiralingManeuver)
                    % We must force the connecting elevation angle to zero to
                    % honor the spiral.
                    el3_deg = 0.;
                end

                % For the connecting angles to be useful they cannot be very
                % close to the starting or ending angles.
                [close, ~, ~, ~, ~] = getAngleInfo(az1_deg, el1_deg, az3_deg, ...
                    el3_deg, threshold_deg);
                if (close)
                    error(['ChangeDirection: Connecting angles (%f, %f) are too ', ...
                        'close to starting angles (%f, %f).'], ...
                        az3_deg, ...
                        el3_deg, ...
                        az1_deg, ...
                        el1_deg);
                end

                [close, ~, ~, ~, ~] = getAngleInfo(az2_deg, el2_deg, az3_deg, ...
                    el3_deg, threshold_deg);
                if (close)
                    error(['ChangeDirection: Connecting angles (%f, %f) are too ', ...
                        'close to ending angles (%f, %f).'], ...
                        az3_deg, ...
                        el3_deg, ...
                        az2_deg, ...
                        el2_deg);
                end
            else
                [az3_deg, el3_deg] = TrajMaker.GetIntermediateAntipodalAngles(...
                    az1_deg, el1_deg, az2_deg, el2_deg);
                warning(['ChangeDirection: No connecting angles specified for ', ...
                    'antipodal angles (%f, %f) and (%f, %f). Automatically using ', ...
                    'angles (%f, %f) to complete the great circle.'], ...
                    az1_deg, ...
                    el1_deg, ...
                    az2_deg, ...
                    el2_deg, ...
                    az3_deg, ...
                    el3_deg);
            end

            % The code that follows relies on pqAngle_deg. Changing q to 
            % calculate a useful v and u shouldn't break anything.
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

        if (anglePq_deg < (2 * rampDeltaTheta_deg))
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
        rampDeltaT_s = acceleration_gs / jerk_gsps; % time to ramp-up/ramp-down

        rampDeltaSpeed_mps = (m_mps3 / 2) * rampDeltaT_s^2; % b = 0

        achievedMaxAcc_mps2 = acceleration_gs * 9.8;
        achievedRampDeltaSpeed_mps = rampDeltaSpeed_mps;
        achievedRampDeltaT_s = rampDeltaT_s;
        
        if (magDeltaSpeed_mps < (2 * rampDeltaSpeed_mps))
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
    
    % Given two angles in spherical coordinates (azimuth and elevation relative
    % to local north), a starting point, changing speed, maximum acceleration
    % and jerk, and a nominal update rate, compute the points along the
    % trajectory, an arc of a great circle with varying radius, maintaining
    % nearly continuous acceleration. Link centripetal and transverse
    % acceleration so that they maintain constant proportionality with respect
    % to each other, so that speed and orientation both arrive at their final
    % values simultaneously.
    function obj = ChangeDirectionAndSpeed(...
        obj, ...
        startingTime_s, ...
        finalBearing_deg, ...
        finalPitch_deg, ...
        finalSpeed_mps, ...
        varargin)

        % Add dependencies to path.
        addpath('dependencies');

        obj = obj.InitializeOutputFile();

        % Process optional input.
        options = ProcessVarargin(obj, 'ChangeDirectionAndSpeed', varargin{:});

        acceleration_gs = options.acceleration_gs;
        jerk_gsps = options.jerk_gsps;
        requestSpiral = options.requestSpiral;

        if (isfield(options, 'candidateString'))
            candidateString = options.candidateString;
        end

        % Sanitization.
        [isValid, message] = TrajMaker.IsTimeInputValid(startingTime_s);
        if (~isValid)
            error('ChangeDirectionAndSpeed: invalid starting time: %s', message);
        end

        if (startingTime_s < obj.clockTime_s_)
            warning(['ChangeDirectionAndSpeed: starting time (%.3f s) is < internal clock time ', ...
                '(%.3f s). Advancing starting time to clock time.'], ...
                startingTime_s, obj.clockTime_s_);
            startingTime_s = obj.clockTime_s_;
        end

        [isValid, message] = TrajMaker.IsBearingInputValid(finalBearing_deg);
        if (~isValid)
            error('ChangeDirectionAndSpeed: invalid final bearing: %s', message);
        end

        [isValid, message] = TrajMaker.IsPitchInputValid(finalPitch_deg);
        if (~isValid)
            error('ChangeDirectionAndSpeed: invalid final pitch: %s', message);
        end

        [isValid, message] = TrajMaker.IsSpeedInputValid(finalSpeed_mps);
        if (~isValid)
            error('ChangeDirectionAndSpeed: invalid final speed: %s', message);
        end

        [isValid, message] = TrajMaker.IsAccelerationInputValid(acceleration_gs);
        if (~isValid)
            error('ChangeDirectionAndSpeed: invalid acceleration: %s', message);
        end

        if (acceleration_gs > obj.maxAcc_gs_)
            warning(['ChangeDirectionAndSpeed: acceleration (%f g''s) is > max acceleration ', ...
                '(%f g''s). Capping acceleration to max acceleration.'], ...
                acceleration_gs, obj.maxAcc_gs_);
            acceleration_gs = obj.maxAcc_gs_;
        end

        [isValid, message] = TrajMaker.IsJerkInputValid(jerk_gsps);
        if (~isValid)
            error('ChangeDirectionAndSpeed: invalid jerk: %s', message);
        end

        if (jerk_gsps > obj.maxJerk_gsps_)
            warning(['ChangeDirectionAndSpeed: jerk (%f g''s/s) is > max jerk (%f g''s/s). ', ...
                'Capping jerk to max jerk.'], jerk_gsps, obj.maxJerk_gsps_);
            jerk_gsps = obj.maxJerk_gsps_;
        end

        % Make sure both orientation and direction actually need to change.
        az1_deg = obj.bearing_deg_;
        el1_deg = obj.pitch_deg_;
        az2_deg = finalBearing_deg;
        el2_deg = finalPitch_deg;

        % Check for a spiraling maneuver request.
        spiralingManeuver = false;
        if (requestSpiral)
            % Only allow spiraling for requests whose final pitch matches the
            % current pitch.
            if (finalPitch_deg == obj.pitch_deg_)
                spiralingManeuver = true;
            else
                error(['ChangeDirectionAndSpeed: Spiraling cannot be honored ', ...
                    'because final pitch (%f deg) does not equal current ', ...
                    'pitch (%f deg).'], ...
                    finalPitch_deg, ...
                    obj.pitch_deg_);
            end
        end

        if (spiralingManeuver)
            el1_deg = 0.;
            el2_deg = 0.;
        end

        threshold_deg = 0.1;
        [pointsAreClose, pointsAreAntipodal, p, q, anglePq_deg] = ...
            getAngleInfo(az1_deg, el1_deg, az2_deg, el2_deg, threshold_deg);

        deltaSpeed_mps = finalSpeed_mps - obj.speed_mps_;
        magDeltaSpeed_mps = abs(deltaSpeed_mps);

        threshold_mps = 0.1;
        needDirectionChange = ~pointsAreClose;
        needSpeedChange = magDeltaSpeed_mps > threshold_mps;

        if (~needDirectionChange && ~needSpeedChange)
            warning(['ChangeDirectionAndSpeed: delta angle (%f deg) and delta ', ...
                'speed (%f mps) are both too small. Aborting...'], ...
                anglePq_deg, deltaSpeed_mps);
            return;
        elseif (needDirectionChange && ~needSpeedChange)
            warning(['ChangeDirectionAndSpeed: delta speed (%f mps) is too small. ', ...
                'Calling ChangeDirection instead...'], deltaSpeed_mps);
            obj = obj.ChangeDirection(...
                startingTime_s, ...
                finalBearing_deg, ...
                finalPitch_deg, ...
                varargin{:})
            return;
        elseif (~needDirectionChange && needSpeedChange)
            warning(['ChangeDirectionAndSpeed: delta angle (%f deg) is too small. ', ...
                'Calling ChangeSpeed instead...'], anglePq_deg);
            obj = obj.ChangeSpeed(...
                startingTime_s, ...
                finalSpeed_mps, ...
                acceleration_gs, ...
                jerk_gsps);
            return;
        end

        haveConnectingAngles = isfield(options, 'connectingAz_deg') && ...
            isfield(options, 'connectingEl_deg');

        if (haveConnectingAngles && ~pointsAreAntipodal)
            warning(['ChangeDirection: Connecting angles detected, but the angles ', ...
                '(%f, %f) and (%f, %f) are not antipodal. Ignoring...'], ...
                az1_deg, ...
                el1_deg, ...
                az2_deg, ...
                el2_deg);
        end

        if (pointsAreAntipodal)
            % If valid connecting angles have been defined, use them. Otherwise,
            % fall back to a generic method.
            if (haveConnectingAngles)
                az3_deg = options.connectingAz_deg;
                el3_deg = options.connectingEl_deg;

                if (spiralingManeuver)
                    % We must force the connecting elevation angle to zero to
                    % honor the spiral.
                    el3_deg = 0.;
                end

                % For the connecting angles to be useful they cannot be very
                % close to the starting or ending angles.
                [close, ~, ~, ~, ~] = getAngleInfo(az1_deg, el1_deg, az3_deg, ...
                    el3_deg, threshold_deg);
                if (close)
                    error(['ChangeDirection: Connecting angles (%f, %f) are too ', ...
                        'close to starting angles (%f, %f).'], ...
                        az3_deg, ...
                        el3_deg, ...
                        az1_deg, ...
                        el1_deg);
                end

                [close, ~, ~, ~, ~] = getAngleInfo(az2_deg, el2_deg, az3_deg, ...
                    el3_deg, threshold_deg);
                if (close)
                    error(['ChangeDirection: Connecting angles (%f, %f) are too ', ...
                        'close to ending angles (%f, %f).'], ...
                        az3_deg, ...
                        el3_deg, ...
                        az2_deg, ...
                        el2_deg);
                end
            else
                [az3_deg, el3_deg] = TrajMaker.GetIntermediateAntipodalAngles(...
                    az1_deg, el1_deg, az2_deg, el2_deg);
                warning(['ChangeDirection: No connecting angles specified for ', ...
                    'antipodal angles (%f, %f) and (%f, %f). Automatically using ', ...
                    'angles (%f, %f) to complete the great circle.'], ...
                    az1_deg, ...
                    el1_deg, ...
                    az2_deg, ...
                    el2_deg, ...
                    az3_deg, ...
                    el3_deg);
            end

            % The code that follows relies on pqAngle_deg. Changing q to 
            % calculate a useful v and u shouldn't break anything.
            [qN, qE, qD] = sph2NED_deg(az3_deg, el3_deg, 1.);
            q = [qN, qE, qD];
        end

        % Now that we know the request will not be ignored, it is safe to
        % propagate.
        obj = obj.PropagateToTime(startingTime_s);

        deg2rad = pi / 180.;
        rad2deg = 180. / pi;

        % Normalize the result of the cross products to guarantee unit vectors.
        v = cross(p, q);
        magV = sqrt(v(1)^2 + v(2)^2 + v(3)^2);
        v = v ./ magV;

        u = cross(v, p);
        magU = sqrt(u(1)^2 + u(2)^2 + u(3)^2);
        u = u ./ magU;

        % The first step is to determine how acceleration and jerk should be
        % split between centripetal and translational components, which are
        % orthogonal.

        % Take an iterative approach: perform a binary angular search of
        % increasing precision until a threshold is satisfied. The angle is that
        % between the centripetal acceleration vector and the net acceleration
        % vector. The angle must live between 0 and 90 degrees.

        % If a spiral maneuver has been requested and approved, maintain the
        % ratio between horizontal and vertical velocity. We cannot simply
        % change horizontal velocity alone because this changes pitch. Work in
        % horizontal space for now, and divorce centripetal acceleration from
        % vertical acceleration. Account for vertical behavior later.

        speed1_mps = obj.speed_mps_;
        speed2_mps = finalSpeed_mps;
        if (spiralingManeuver)
            cosPitch = cos(obj.pitch_deg_ * deg2rad);
        end

        accNet_gs = acceleration_gs;
        jerkNet_gsps = jerk_gsps;

        accAngle_deg = 45.0;
        stepSize_deg = 45.0;
        count = 0;
        while (true)

            if (count > 1000)
                error('While loop spinning.');
            end

            lastAccAngle_deg = accAngle_deg;

            if (count > 0)
                lastAngleError_deg = angleError_deg;

                % Move the angle clockwise or counter-clockwise based on the
                % sign of the error.
                if (angleError_deg > 0.)
                    accAngle_deg = accAngle_deg + stepSize_deg;
                elseif (angleError_deg < 0.)
                    accAngle_deg = accAngle_deg - stepSize_deg;
                else
                    % We're lucky!
                    break;
                end

                % Don't allow an angle of 0 or 90 degrees, as this will cause
                % one of the acceleration components to be zero.
                if (accAngle_deg == 0.)
                    accAngle_deg = accAngle_deg + 1e-3;
                elseif (accAngle_deg == 90.)
                    accAngle_deg = accAngle_deg - 1e-3;
                end
            end

            accAngle_rad = accAngle_deg * deg2rad;
            cosAccAngle = cos(accAngle_rad);
            sinAccAngle = sin(accAngle_rad);

            accCentripetal_gs = acceleration_gs * cosAccAngle;
            jerkCentripetal_gsps = jerk_gsps * cosAccAngle;

            accTranslational_gs = acceleration_gs * sinAccAngle;
            jerkTranslational_gsps = jerk_gsps * sinAccAngle;

            [tNet_s, tRamp_s, tInBetween_s] = TrajMaker.TimeRequiredToChangeSpeed(...
                speed1_mps, ...
                speed2_mps, ...
                accTranslational_gs, ...
                jerkTranslational_gsps);

            % This must be done after the call to TimeRequired... so the time
            % calculation isn't affected.
            if (spiralingManeuver)
                accTranslational_gs = accTranslational_gs * cosPitch;
                jerkTranslational_gsps = jerkTranslational_gsps * cosPitch;
            end

            % How much would the great circle angle have changed? Use calculus
            % and physics to find the answer.

            % Centripetal acceleration is always positive, but translational
            % acceleration may be negative. We must include the sign of the
            % translational acceleration for the math to be correct. This also
            % affects translational jerk.
            accTranslational_gs = accTranslational_gs * sign(deltaSpeed_mps);
            jerkTranslational_gsps = jerkTranslational_gsps * sign(deltaSpeed_mps);

            % Part 1: ramp-up
            mT = jerkTranslational_gsps * 9.8;
            mC = jerkCentripetal_gsps * 9.8;
            vT0 = speed1_mps;
            if (spiralingManeuver)
                vT0 = speed1_mps * cosPitch;
            end

            dThetaRampUp_rad = mC / mT * (log(abs(mT / 2 * tRamp_s^2 + vT0)) - ...
                log(abs(vT0)));

            % How much did speed change during the ramp-up? The new speed will
            % serve as the starting speed for the next part.
            dSpeedRampUp_mps = mT / 2 * tRamp_s^2;
            vT0 = vT0 + dSpeedRampUp_mps;

            % Part 2: in between
            dThetaInBetween_rad = 0.;
            dSpeedInBetween_mps = 0.;

            if (tInBetween_s > 0.)
                % Both accelerations were maxed out for this part.
                aT = accTranslational_gs * 9.8;
                aC = accCentripetal_gs * 9.8;

                dThetaInBetween_rad = aC / aT * log(abs(aT * tInBetween_s + vT0) / ...
                    abs(vT0));

                % How much did speed change for this part?
                dSpeedInBetween_mps = aT * tInBetween_s;
            end

            vT0 = vT0 + dSpeedInBetween_mps;

            % Part 3: ramp-down

            % What were the accelerations when the ramp-down began? If there was
            % some in between time, they were maxed out. Otherwise...
            if (tInBetween_s > 0.)
                aT0 = accTranslational_gs * 9.8;
                aC0 = accCentripetal_gs * 9.8;
            else
                aT0 = tRamp_s * mT * 9.8;
                aC0 = tRamp_s * mC * 9.8;
            end

            mT = -jerkTranslational_gsps * 9.8;
            mC = -jerkCentripetal_gsps * 9.8;

            underSqRoot = 2 * mT * vT0 - aT0^2;

            if (underSqRoot > 0.)

                sqRoot = sqrt(underSqRoot);

                val1 = mC / mT * log(abs(mT / 2 * tRamp_s^2 + aT0 * tRamp_s + vT0));
                val2 = ((mT * aC0) - (mC * aT0)) / (mT / 2 * sqRoot);
                val3 = atan((mT * tRamp_s + aT0) / sqRoot);

                thetaEndOfRampDown_rad = val1 + (val2 * val3); % + C

                val1 = mC / mT * log(abs(vT0));
                val3 = atan(aT0 / sqRoot);

                thetaBeginningOfRampDown_rad = val1 + (val2 * val3); % + C

            elseif (underSqRoot < 0.)

                sqRoot = sqrt(aT0^2 - 2 * mT * vT0);

                val1 = mC / mT * log(abs(mT / 2 * tRamp_s^2 + aT0 * tRamp_s + vT0));
                val2 = ((mT * aC0) - (mC * aT0)) / (mT / 2 * sqRoot);
                val3 = atanh((mT * tRamp_s + aT0) / sqRoot);

                thetaEndOfRampDown_rad = val1 - (val2 * val3); % + C

                val1 = mC / mT * log(abs(vT0));
                val3 = atanh(aT0 / sqRoot);

                thetaBeginningOfRampDown_rad = val1 - (val2 * val3); % + C

            else % if (underSqRoot == 0.)

                val1 = mC / mT * log(abs(mT / 2 * tRamp_s^2 + aT0 * tRamp_s + vT0));
                val2 = ((mT * aC0) - (mC * aT0)) / (mT / 2 * (mT * tRamp_s + aT0));

                thetaEndOfRampDown_rad = val1 - val2; % + C

                val1 = mC / mT * log(abs(vT0));
                val2 = ((mT * aC0) - (mC * aT0)) / (mT / 2 * aT0);

                thetaBeginningOfRampDown_rad = val1 - val2; % + C

            end

            dThetaRampDown_rad = thetaEndOfRampDown_rad - thetaBeginningOfRampDown_rad;

            dThetaNet_rad = dThetaRampUp_rad + dThetaInBetween_rad + dThetaRampDown_rad;
            dThetaNet_deg = dThetaNet_rad * rad2deg;

            % We know how much the great circle angle must change to solve the
            % problem.
            angleError_deg = dThetaNet_deg - anglePq_deg;

            if (count > 0)
                stepSize_deg = stepSize_deg / 2.;

                if (abs(angleError_deg) > abs(lastAngleError_deg))
                    % The error got worse -- go back.
                    accAngle_deg = lastAccAngle_deg;
                    angleError_deg = lastAngleError_deg;
                else
                    % The error improved.
                    % Break out once the angle error is small enough.
                    if (abs(angleError_deg) < 1e-3)
                        break;
                    end
                end
            end

            count = count + 1;

        end

        % Translational acceleration and jerk may have been made negative for
        % the while loop to work. Now we need them to be positive.
        accTranslational_gs = abs(accTranslational_gs);
        jerkTranslational_gsps = abs(jerkTranslational_gsps);

        k = accCentripetal_gs / accTranslational_gs;

        if (spiralingManeuver)
            accTranslational_gs = accTranslational_gs / cosPitch;
            jerkTranslational_gsps = jerkTranslational_gsps / cosPitch;
        end

        % Now we know how acceleration and jerk should be split between
        % centripetal and translational components. Because the ChangeDirection
        % and ChangeSpeed methods use the same algorithm to control changes in
        % acceleration, and because we have made the two parts of the combined
        % maneuver take the same amount of time, we may solve for acceleration
        % from either method and simply multiply by a scale factor to obtain
        % acceleration for the other method.

        % Find the acceleration and speed for the translational component, which
        % would be found from ChangeSpeed. The speed found will become the
        % tangential velocity for the combined maneuver in the next part.

        % Until later, simplify calculations by assuming that translational
        % acceleration is positive. Then, change the sign of the calculated
        % speed if the acceleration is negative.

        m_mps3 = jerkTranslational_gsps * 9.8;
        rampDeltaT_s = accTranslational_gs / jerkTranslational_gsps; % time to ramp-up/ramp-down
        rampDeltaSpeed_mps = (m_mps3 / 2) * rampDeltaT_s^2; % b = 0

        achievedMaxAccTranslational_mps2 = accTranslational_gs * 9.8;
        achievedRampDeltaSpeed_mps = rampDeltaSpeed_mps;
        achievedRampDeltaT_s = rampDeltaT_s;

        if (magDeltaSpeed_mps < (2 * rampDeltaSpeed_mps))
            % There is not enough velocity space to ramp-up to the requested acceleration.
            % We must ramp-up and down to a lesser acceleration.
            achievedRampDeltaSpeed_mps = magDeltaSpeed_mps / 2.;

            % Solving for the time it takes to realize this new speed will inform the
            % smaller acceleration.
            achievedRampDeltaT_s = sqrt(2 / m_mps3 * achievedRampDeltaSpeed_mps);
            achievedMaxAccTranslational_mps2 = m_mps3 * achievedRampDeltaT_s;
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
            timeInBetween_s = deltaSpeedInBetween_mps / achievedMaxAccTranslational_mps2;

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
            accT_mps2 = zeros(1, 2 * N_ramp + N_inBetween);
        else
            % The last point of the ramp-up is the first point of the ramp-down.
            t_s = zeros(1, 2 * N_ramp - 1);
            speed_mps = zeros(1, 2 * N_ramp - 1);
            accT_mps2 = zeros(1, 2 * N_ramp - 1);
        end

        % Stage 1: ramp-up.
        t_s(1:N_ramp) = linspace(0., achievedRampDeltaT_s, N_ramp);
        speed_mps(1:N_ramp) = (m_mps3 / 2) .* t_s(1:N_ramp) .^ 2; % b = 0
        accT_mps2(1:N_ramp) = m_mps3 .* t_s(1:N_ramp); % b = 0

        % Stage 2: in between.
        if (N_inBetween > 0)
            t_s((N_ramp + 1):(N_ramp + N_inBetween)) = tInBetween_s;
            speed_mps((N_ramp + 1):(N_ramp + N_inBetween)) = speedInBetween_mps;
            accT_mps2((N_ramp + 1):(N_ramp + N_inBetween)) = achievedMaxAccTranslational_mps2;
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

        m_mps3 = -m_mps3;
        v0_mps = magDeltaSpeed_mps - achievedRampDeltaSpeed_mps;

        b_mps2 = achievedMaxAccTranslational_mps2;

        speed_mps(N_startOfRampDown:end) = (m_mps3 / 2) .* t_s(1:N_ramp) .^ 2 + ...
            b_mps2 .* t_s(1:N_ramp) + v0_mps;

        accT_mps2(N_startOfRampDown:end) = m_mps3 .* t_s(1:N_ramp) + b_mps2;

        % Thus far, calculations have been simplified by assuming that the
        % acceleration is positive. If acceleration is negative, change the sign
        % of speed_mps.
        speed_mps = speed_mps .* sign(deltaSpeed_mps);

        % We have also assumed that the starting speed is zero. Add the true
        % starting speed.
        speed_mps = speed_mps + speed1_mps;

        % Now we are ready to proceed with centripetal acceleration. As
        % mentioned above, we may simply multiply translational acceleration by
        % a scale factor to obtain centripetal acceleration.

        accC_mps2 = k .* accT_mps2;

        omega_radps = accC_mps2 ./ speed_mps;

        dT_s = diff(t_s);
        theta_rad = zeros(length(omega_radps), 1);
        for i = 2:1:length(omega_radps)
            theta_rad(i) = theta_rad(i-1) + omega_radps(i) * dT_s(i-1);
        end

        % From earlier:
        % Thus, the vectors P and U are orthogonal, and a parametric expression
        % gives the points W on the great circle of interest, from P:
        % W = P*cos(theta) + U*sin(theta).

        sinTheta = sin(theta_rad);
        cosTheta = cos(theta_rad);

        velocityN_mps = speed_mps' .* (p(1) .* cosTheta + u(1) .* sinTheta);
        velocityE_mps = speed_mps' .* (p(2) .* cosTheta + u(2) .* sinTheta);
        velocityD_mps = speed_mps' .* (p(3) .* cosTheta + u(3) .* sinTheta);

        if (spiralingManeuver)
            velocityD_mps = -speed_mps' .* sin(obj.pitch_deg_ * deg2rad);
            velocityE_mps = velocityE_mps .* cosPitch;
            velocityN_mps = velocityN_mps .* cosPitch;
        end

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
        obj.bearing_deg_ = az2_deg;
        obj.speed_mps_ = finalSpeed_mps;

        if (~spiralingManeuver)
            % If this is a spiraling maneuver, el2_deg will have been set to
            % zero even if this is not the desired final pitch. Do not capture
            % this expediency.
            obj.pitch_deg_ = el2_deg;
        end

    end % ChangeDirectionAndSpeed

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