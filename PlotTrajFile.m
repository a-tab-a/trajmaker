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

% Create a 3D position-velocity quiver plot from a trajectory file made by
% TrajMaker.m.
function PlotTrajFile(filePath)

    % Add dependencies to path.
    addpath('dependencies');
    
    if (nargin == 0)
        [data, isNED, filePath] = LoadTrajFile;
    else
        [data, isNED, ~] = LoadTrajFile(filePath);
    end
    
    titleString = 'Position-Velocity Quiver';
    GetFig(titleString);
    clf;
    hold on;
    if (isNED)
        plot3(data.PosE_m ./ 1e3, data.PosN_m ./ 1e3, -data.PosD_m ./ 1e3, 'r');
        quiver3(data.PosE_m ./ 1e3, data.PosN_m ./ 1e3, -data.PosD_m ./ 1e3, ...
            data.VelE_mps, data.VelN_mps, -data.VelD_mps, 'r');
    else % NUE
        plot3(data.PosE_m ./ 1e3, data.PosN_m ./ 1e3, data.PosU_m ./ 1e3, 'r');
        quiver3(data.PosE_m ./ 1e3, data.PosN_m ./ 1e3, data.PosU_m ./ 1e3, ...
            data.VelE_mps, data.VelN_mps, data.VelU_mps, 'r');
    end
    hold off;
    xlabel('East (km)');
    ylabel('North (km)');
    zlabel('Up (km)');
    grid on;
    
    % Include the file name in the title.
    [~, name, ext] = fileparts(filePath);
    titleCell = {[name, ext, ': '], titleString};
    title(titleCell);

end % PlotTrajFile