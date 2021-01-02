classdef hNRPhyRxBuffer < handle
%hNRPhyRxBuffer Create a Phy signal reception buffer object. This class
%implements the buffering of received signals and adding of interfering
%signals to get the resultant signal
%
%   hNRPhyRxBuffer methods:
%
%   addWaveform           - Store the received waveform along with metadata
%
%   getReceivedWaveform   - Return the received waveform after applying
%                           interference
%
%   setReceptionOn        - Set the reception start flag
%
%   setReceptionOff       - Reset the reception start flag
%
%   hNRPhyRxBuffer properties:
%
%   BufferSize   - Maximum number of signals to be stored in the buffer
%
%   Example 1:
%   % Create a hNRPhyRxBuffer object with default properties.
%
%   rxBufferObj = hNRPhyRxBuffer
%
%   Example 2:
%   % Create a hNRPhyRxBuffer object specifying a buffer size of 100.
%
%   rxBufferObj = hNRPhyRxBuffer('BufferSize', 100);
%
%   Example 3:
%   % Create a hNRPhyRxBuffer object.
%
%   rxBufferObj = hNRPhyRxBuffer;
%
%   % Set reception on and current time is 2500 microseconds
%
%   setReceptionOn(rxBufferObj, 2500);
%
%   % Create a sample signal and add it to the buffer
%
%   signalInfo = struct('Waveform', complex(randn(15360, 1),randn(15360, 1)),...
%   'NumSamples', 15360, 'SampleRate', 15360000, 'StartTime', 3000);
% 
%   addWaveform(rxBufferObj, signalInfo);
%
%   % Get the waveform from the buffer after applying interference. The
%   % reception start time is 3000 microseconds, reception duration is 1000
%   % microseconds, with a sample rate of 15360000
%
%   receivedWaveform = getReceivedWaveform(rxBufferObj, 3000, 1000, 15360000);
%
%  % Set reception off
%
%   setReceptionOff(rxBufferObj);

%   Copyright 2020 The MathWorks, Inc.

%#codegen

    properties
        %BufferSize Maximum number of signals to be stored.
        % The default value is 7. (To model a 7 cluster scenario, where
        % there can be 7 co-channel cells).
        %
        BufferSize {mustBeNonempty, mustBeInteger, mustBeGreaterThan(BufferSize, 0)} = 7
    end

    properties (Access = private)
        %ReceivedSignals Buffer to store the received signals
        ReceivedSignals

        %RxStarted Flag to indicate reception status. It is set to true
        %when reception is in progress
        RxStarted (1, 1) logical = false
    end

    methods (Access = public)

        function obj = hNRPhyRxBuffer(varargin)
            %hNRPhyRxBuffer Construct an instance of this class

            % Set name-value pairs
            for idx = 1:2:nargin
                obj.(varargin{idx}) = varargin{idx+1};
            end

            % Initialize the signal structure
            signal = struct('Waveform', complex(0,0), ...
                'NumSamples', 0, ...
                'SampleRate', 0, ...
                'StartTime', 0, ...
                'EndTime', 0);
            signal.Waveform = complex(zeros(2, 1));% To support codegen

            % To store the received signals and the associated metadata
            obj.ReceivedSignals = repmat(signal, obj.BufferSize, 1);
        end

        function setReceptionOn(obj, currentTime)
            %setReceptionOn Set the reception start flag
            %
            %   setReceptionOn(OBJ, CURRENTTIME) Sets the reception flag and
            %   removes the obsolete signals from the buffer
            %
            %   CURRENTTIME - Current time (in microseconds)

            obj.RxStarted = true;

            % Remove the obsolete signals
            removeObsoleteWaveforms(obj, currentTime);
        end

        function setReceptionOff(obj)
            %setReceptionOff Reset the reception start flag
            %
            %   setReceptionOff(OBJ) Resets the reception start flag

            % Reset the reception start flag
            obj.RxStarted = false;
        end

        function addWaveform(obj, signalInfo)
            %addWaveform Add the received signal to the buffer
            %
            %   addWaveform(OBJ, SIGNALINFO) Adds the received signal to
            %   the buffer
            %
            %   SIGNALINFO is a structure with these fields:
            %       Waveform    : IQ samples of the received signal. It is
            %                     a column vector of complex values
            %       NumSamples  : Length of the waveform (number of IQ
            %                     samples). It is a scalar and represents
            %                     the number of samples in the waveform
            %       SampleRate  : Sample rate of the waveform. It is a
            %                     scalar
            %       StartTime   : Current timestamp of the receiver at
            %                     signal entry (in microseconds). It is a
            %                     scalar

            if ~obj.RxStarted % If reception is not started
                % Remove obsolete signals with end times earlier than the
                % current signal start time. It clears all the obsolete
                % signals automatically when the node is inactive.
                removeObsoleteWaveforms(obj, signalInfo.StartTime);
            end

            % Get an index in the signal buffer to store the received
            % signal
            idx = getStoreIndex(obj);

            if idx ~= 0
                % Store the signal along with metadata
                obj.ReceivedSignals(idx).Waveform = signalInfo.Waveform;
                obj.ReceivedSignals(idx).NumSamples = signalInfo.NumSamples;
                obj.ReceivedSignals(idx).SampleRate = signalInfo.SampleRate;
                obj.ReceivedSignals(idx).StartTime = signalInfo.StartTime;
                % Sample duration (in microseconds)
                sampleDuration = 1e6 * (1 / signalInfo.SampleRate);
                waveformDuration = signalInfo.NumSamples * sampleDuration;
                % Signal end time
                obj.ReceivedSignals(idx).EndTime = signalInfo.StartTime + waveformDuration - 1;
            else
                sprintf(['Reception buffer is full. Increase the current ',...
                'buffer size to greater than {%d}.'], int64(obj.BufferSize))
            end

        end

        function nrWaveform = getReceivedWaveform(obj, rxStartTime, rxDuration, sampleRate)
            %getReceivedWaveform Return the received waveform for the
            %reception duration
            %
            %   NRWAVEFORM = getReceivedWaveform(OBJ, RXSTARTTIME, RXDURATION, SAMPLERATE)
            %   Returns the NR waveform
            %
            %   RXSTARTTIME  - Reception start time of receiver (in microseconds)
            %
            %   RXDURATION   - Duration of reception (in microseconds). It
            %   is a scalar
            %
            %   SAMPLERATE - Sample rate of the waveform. It is a
            %   scalar
            %
            %   NRWAVEFORM - Represents resultant waveform. It is a column
            %   vector of IQ samples

            if ~obj.RxStarted % If reception is not started
                % Return the empty waveform
                nrWaveform = [];
                return;
            end

            % Reception end time (in microseconds)
            rxEndTime = rxStartTime + rxDuration - 1;
            % Get indices of the overlapping signals
            waveformIndices = getOverlappingSignalIdxs(obj, rxStartTime, rxEndTime);

            % Get the resultant waveform from interfering waveforms
            if isempty(waveformIndices)
                % Return the empty waveform
                nrWaveform = [];
            else
                % Calculate the number of samples per microsecond
                numSamples = sampleRate / 1e6;
                % Initialize the waveform
                waveformLength = round(rxDuration * numSamples);
                nrWaveform = complex(zeros(waveformLength, 1));

                for idx = 1:length(waveformIndices)
                    % Fetch received signal
                    receivedSignal = obj.ReceivedSignals(waveformIndices(idx));
                    % Sample duration of the received signal
                    if sampleRate ~= receivedSignal.SampleRate
                        % Resample the waveform
                        receivedWaveform = resample(receivedSignal.Waveform, sampleRate, receivedSignal.SampleRate);
                    else
                        receivedWaveform = receivedSignal.Waveform;
                    end

                    % Calculate the number of overlapping samples
                    overlapStartTime = max(rxStartTime, receivedSignal.StartTime);
                    overlapEndTime = min(rxEndTime, receivedSignal.EndTime) + 1;
                    numOverlapSamples = round((overlapEndTime - overlapStartTime) * numSamples);

                    % Signal received after reception start
                    if rxStartTime < receivedSignal.StartTime

                        % Calculate the overlapping start and end index of
                        % the received waveform IQ samples
                        receivedSignalStartIdx = 1;
                        receivedSignalEndIdx = numOverlapSamples;

                        % Calculate the overlapping start and end index of the
                        % actual waveform IQ samples
                        if rxEndTime <= receivedSignal.EndTime
                            % Reception end time is less than or equal to the
                            % received signal end time
                            sampleStartIdx = waveformLength - numOverlapSamples + 1;
                            sampleEndIdx = waveformLength;
                        else
                            % Reception end time is greater than the received
                            % signal end time
                            sampleStartIdx = round((receivedSignal.StartTime - rxStartTime) * numSamples) + 1;
                            sampleEndIdx = sampleStartIdx + numOverlapSamples - 1;
                        end

                    else  % Signal received before reception start

                        % Calculate the overlapping start and end index of
                        % actual waveform IQ samples
                        sampleStartIdx = 1;
                        sampleEndIdx = numOverlapSamples;

                        % Calculate the overlapping start and end index of
                        % received waveform IQ samples
                        receivedSignalStartIdx = round((rxStartTime - receivedSignal.StartTime) * numSamples) + 1;
                        receivedSignalEndIdx = receivedSignalStartIdx + numOverlapSamples - 1;
                    end

                    % Combine the IQ samples
                    nrWaveform(sampleStartIdx:sampleEndIdx, 1) = nrWaveform(sampleStartIdx:sampleEndIdx, 1) + ...
                        receivedWaveform(receivedSignalStartIdx:receivedSignalEndIdx, 1);
                end
            end

        end

    end

    methods (Access = private)

        function storeIdx = getStoreIndex(obj)
            %getStoreIndex Get an index to store the waveform in the buffer

            storeIdx = 0;
            for idx = 1:obj.BufferSize
                % Get a free index in the buffer
                if obj.ReceivedSignals(idx).NumSamples == 0
                    storeIdx = idx;
                    break;
                end
            end
        end

        function interferedIdxs = getOverlappingSignalIdxs(obj, startTime, endTime)
            %getOverlappingSignalIdxs Get indices of the received signals from stored
            %buffer based on reception start and end time

            % Initialize the vector to store indices of overlapping signals
            interferingIdxs = zeros(obj.BufferSize, 1);
            currentOverlapCount = 0;
            for idx = 1:obj.BufferSize
                % Fetch valid signals
                if obj.ReceivedSignals(idx).NumSamples > 0
                    % Fetch index of the overlapping signals based on the start time
                    % and end time
                    if (startTime <= obj.ReceivedSignals(idx).EndTime) && ...
                            endTime >= (obj.ReceivedSignals(idx).StartTime)
                        currentOverlapCount = currentOverlapCount + 1;
                        % Add the index of overlapping signal
                        interferingIdxs(currentOverlapCount) = idx;
                    end
                end
            end
            % Return the indices of the stored signals
            interferedIdxs = interferingIdxs(interferingIdxs>0);
        end

        function removeObsoleteWaveforms(obj, currentTime)
            %removeObsoleteWaveforms Remove the signals from the stored
            %buffer whose end time is less than the current time

            for idx = 1:obj.BufferSize
                % Remove the signal
                if obj.ReceivedSignals(idx).NumSamples > 0 && obj.ReceivedSignals(idx).EndTime < currentTime
                    % Reset the NumSamples property of the signal, to
                    % indicate that the signal is obsolete
                    obj.ReceivedSignals(idx).NumSamples = 0;
                end
            end
        end
    end
end