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

% Load a trajectory file made by TrajMaker.m and generate some useful plots to
% validate trajectory behavior and realistic acceleration.
function ValidateTrajFile(filePath)

    % Add dependencies to path.
    addpath('dependencies');
    
    if (nargin == 0)
        [data, isNED, filePath] = LoadTrajFile;
    else
        [data, isNED, ~] = LoadTrajFile(filePath);
    end
    
    % Include the file name in the title.
    [~, name, ext] = fileparts(filePath);
    
    % Position
    titleString = 'Position';
    GetFig(titleString);
    clf;
    
    ax1 = subplot(3,1,1);
    plot(data.Time_s, data.PosN_m ./ 1e3, 'r');
    ylabel('PosN (km)');
    title([name, ext, ': ', titleString]);
    grid on;
    
    ax2 = subplot(3,1,2);
    plot(data.Time_s, data.PosE_m ./ 1e3, 'b');
    ylabel('PosE (km)');
    grid on;
    
    ax3 = subplot(3,1,3);
    if (isNED)
        plot(data.Time_s, data.PosD_m ./ 1e3, 'g');
        ylabel('PosD (km)');
    else % NUE
        plot(data.Time_s, data.PosU_m ./ 1e3, 'g');
        ylabel('PosU (km)');
    end
    xlabel('Time (s)');
    grid on;
    linkaxes([ax1, ax2, ax3], 'x');
    
    % Velocity
    titleString = 'Velocity';
    GetFig(titleString);
    clf;
    
    ax4 = subplot(4,1,1);
    dT_s = diff(data.Time_s);
    velFromPosN_mps = diff(data.PosN_m) ./ dT_s;
    hold on;
    plot(data.Time_s, data.VelN_mps, 'r');
    plot(data.Time_s(1:end-1), velFromPosN_mps, 'or');
    hold off;
    ylabel('VelN (mps)');
    titleCell = {[name, ext, ': ', titleString], ' (''o'' = from position)'};
    title(titleCell);
    grid on;
    
    ax5 = subplot(4,1,2);
    velFromPosE_mps = diff(data.PosE_m) ./ dT_s;
    hold on;
    plot(data.Time_s, data.VelE_mps, 'b');
    plot(data.Time_s(1:end-1), velFromPosE_mps, 'ob');
    hold off;
    ylabel('VelE (mps)');
    grid on;
    
    ax6 = subplot(4,1,3);
    hold on;
    if (isNED)
        velFromPosD_mps = diff(data.PosD_m) ./ dT_s;
        plot(data.Time_s, data.VelD_mps, 'g');
        plot(data.Time_s(1:end-1), velFromPosD_mps, 'og');
        ylabel('VelD (mps)');
    else % NUE
        velFromPosU_mps = diff(data.PosU_m) ./ dT_s;
        plot(data.Time_s, data.VelU_mps, 'g');
        plot(data.Time_s(1:end-1), velFromPosU_mps, 'og');
        ylabel('VelU (mps)');
    end
    hold off;
    grid on;
    
    ax7 = subplot(4,1,4);
    if (isNED)
        velMag_mps = sqrt(data.VelN_mps .^ 2 + data.VelE_mps .^ 2 + ...
            data.VelD_mps .^ 2);
        velMagFromPos_mps = sqrt(velFromPosN_mps .^ 2 + velFromPosE_mps .^ 2 + ...
            velFromPosD_mps .^ 2);
    else % NUE
        velMag_mps = sqrt(data.VelN_mps .^ 2 + data.VelE_mps .^ 2 + ...
            data.VelU_mps .^ 2);
        velMagFromPos_mps = sqrt(velFromPosN_mps .^ 2 + velFromPosE_mps .^ 2 + ...
            velFromPosU_mps .^ 2);
    end
    hold on;
    plot(data.Time_s, velMag_mps, 'm');
    plot(data.Time_s(1:end-1), velMagFromPos_mps, 'om');
    hold off;
    ylabel('|Vel| (mps)');
    xlabel('Time (s)');
    grid on;
    linkaxes([ax4, ax5, ax6, ax7], 'x');
    
    % Orientation
    titleString = 'Orientation';
    GetFig(titleString);
    clf;

    rad2deg = 180. / pi;
    bearing_deg = atan2(data.VelE_mps, data.VelN_mps) .* rad2deg;
    horizontalVelocity_mps = sqrt(data.VelN_mps .^ 2 + data.VelE_mps .^ 2);
    if (isNED)
        pitch_deg = atan(-data.VelD_mps ./ horizontalVelocity_mps) .* rad2deg;
    else % NUE
        pitch_deg = atan(data.VelU_mps ./ horizontalVelocity_mps) .* rad2deg;
    end

    ax8 = subplot(2,1,1);
    plot(data.Time_s, bearing_deg, 'r');
    ylabel('Bearing (deg)');
    titleCell = {[name, ext, ': ', titleString]};
    title(titleCell);
    grid on;

    ax9 = subplot(2,1,2);
    plot(data.Time_s, pitch_deg, 'b');
    ylabel('Pitch (deg)');
    xlabel('Time (s)');
    grid on;
    linkaxes([ax8, ax9], 'x');

    % Acceleration
    GetFig('Acceleration');
    clf;
    
    ax10 = subplot(4,1,1);
    accFromVelN_gs = diff(data.VelN_mps) ./ dT_s ./ 9.8;
    dT2_s = diff(data.Time_s(1:end-1));
    accFromPosN_gs = diff(velFromPosN_mps) ./ dT2_s ./ 9.8;
    hold on;
    plot(data.Time_s(1:end-1), accFromVelN_gs, 'r');
    plot(data.Time_s(1:end-2), accFromPosN_gs, 'or');
    hold off;
    ylabel('AccN (g''s)');
    titleString = 'Acceleration from Velocty & Position';
    titleCell = {[name, ext, ': ', titleString], ' (''o'' = from position)'};
    title(titleCell);
    grid on;
    
    ax11 = subplot(4,1,2);
    accFromVelE_gs = diff(data.VelE_mps) ./ dT_s ./ 9.8;
    accFromPosE_gs = diff(velFromPosE_mps) ./ dT2_s ./ 9.8;
    hold on;
    plot(data.Time_s(1:end-1), accFromVelE_gs, 'g');
    plot(data.Time_s(1:end-2), accFromPosE_gs, 'og');
    hold off;
    ylabel('AccE (g''s)');
    grid on;
    
    ax12 = subplot(4,1,3);
    if (isNED)
        accFromVelD_gs = diff(data.VelD_mps) ./ dT_s ./ 9.8;
        accFromPosD_gs = diff(velFromPosD_mps) ./ dT2_s ./ 9.8;
        hold on;
        plot(data.Time_s(1:end-1), accFromVelD_gs, 'b');
        plot(data.Time_s(1:end-2), accFromPosD_gs, 'ob');
        hold off;
        ylabel('AccD (g''s)');
    else % NUE
        accFromVelU_gs = diff(data.VelU_mps) ./ dT_s ./ 9.8;
        accFromPosU_gs = diff(velFromPosU_mps) ./ dT2_s ./ 9.8;
        hold on;
        plot(data.Time_s(1:end-1), accFromVelU_gs, 'b');
        plot(data.Time_s(1:end-2), accFromPosU_gs, 'ob');
        hold off;
        ylabel('AccU (g''s)');
    end
    grid on;
    
    ax13 = subplot(4,1,4);
    if (isNED)
        accMagFromVel_gs = sqrt(accFromVelN_gs .^ 2 + accFromVelE_gs .^ 2 + ...
            accFromVelD_gs .^ 2);
        accMagFromPos_gs = sqrt(accFromPosN_gs .^ 2 + accFromPosE_gs .^ 2 + ...
            accFromPosD_gs .^ 2);
    else % NUE
        accMagFromVel_gs = sqrt(accFromVelN_gs .^ 2 + accFromVelE_gs .^ 2 + ...
            accFromVelU_gs .^ 2);
        accMagFromPos_gs = sqrt(accFromPosN_gs .^ 2 + accFromPosE_gs .^ 2 + ...
            accFromPosU_gs .^ 2);
    end
    hold on;
    plot(data.Time_s(1:end-1), accMagFromVel_gs, 'm');
    plot(data.Time_s(1:end-2), accMagFromPos_gs, 'om');
    hold off;
    ylabel('|Acc| (g''s)');
    xlabel('Time (s)');
    grid on;
    linkaxes([ax10, ax11, ax12, ax13], 'x');

end % ValidateTrajFile