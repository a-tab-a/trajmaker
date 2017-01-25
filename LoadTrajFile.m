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

% Load a trajectory file made by TrajMaker.m.
function [data, isNED, filePath] = LoadTrajFile(filePath)
    
    if (nargin == 0)
        % Prompt the user to select a file.
        if (exist('output', 'dir') == 7)
            searchString = fullfile('output', '*.traj');
        else
            searchString = '*.traj';
        end
        
        [fileName, fileDir, ~] = uigetfile(searchString);
        if (~ischar(fileName))
            error('User canceled file selection dialog.');
        end
        filePath = fullfile(fileDir, fileName);
    elseif (~ischar(filePath))
        error('filePath must be a string!');
    end
    
    [~, ~, ext] = fileparts(filePath);
    if (~strcmp(ext, '.traj'))
        error('Invalid file extension ''%s''. Only .traj files may be loaded.', ext);
    end
    
    [fID, msg] = fopen(filePath, 'r');
    if (fID == -1)
        error('The file ''%s'' could not be opened. System message: ''%s''.', ...
            filePath, msg);
    end
    
    % Attempt to parse the header line.
    header = fgetl(fID);
    fields = strsplit(header);
    
    try
        % Examine the header for correctness.
        if (length(fields) ~= 7)
            error('Invalid file ''%s''. Incorrect number of fields (columns).', filePath);
        end
        
        invalidHeader = false;
        isNED = true;

        if (~strcmpi(fields{1}, 'time_s'))
            invalidHeader = true;
        end
        
        if (~strcmpi(fields{2}, 'posn_m'))
            invalidHeader = true;
        end
        
        if (strcmpi(fields{3}, 'pose_m'))
            isNED = true;
        elseif (strcmpi(fields{3}, 'posu_m'))
            isNED = false;
        else
            invalidHeader = true;
        end
        
        if ((isNED && ~strcmpi(fields{4}, 'posd_m')) || ...
            (~isNED && ~strcmpi(fields{4}, 'pose_m')))
            invalidHeader = true;
        end
        
        if (~strcmpi(fields{5}, 'veln_mps'))
            invalidHeader = true;
        end
        
        if ((isNED && ~strcmpi(fields{6}, 'vele_mps')) || ...
            (~isNED && ~strcmpi(fields{6}, 'velu_mps')))
            invalidHeader = true;
        end
        
        if ((isNED && ~strcmpi(fields{7}, 'veld_mps')) || ...
            (~isNED && ~strcmpi(fields{7}, 'vele_mps')))
            invalidHeader = true;
        end
        
        if (invalidHeader)
            error('The file ''%s'' is not a valid trajectory file.', filePath);
        end
        
        formatString = [repmat('%f\t', 1, 6), '%f'];
        dataSize = [7, Inf];
        fileData = fscanf(fID, formatString, dataSize);
        
        fclose(fID);
    
    catch (exc)
        fclose(fID);
        rethrow(exc);
    end
    
    for i = 1:1:length(fields)
        data.(fields{i}) = fileData(i,:);
    end
    
end % LoadTrajFile