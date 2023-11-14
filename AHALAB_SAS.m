classdef AHALAB_SAS < handle
    % AHALAB_SAS is a class for running a Staochastic Approximation Staircase
    % (SAS) procedure.
    % SAS is a method for estimating the threshold of a stimulus based on a binary response (e.g. correct/incorrect). 
    % It is a sequential procedure that converges to the threshold of a stimulus by
    % adjusting the stimulus intensity based on the response of the observer for the previous stimuli.
    % 
    % Defualt equation used:
    %                         C
    %   x_nplus1 =  x_n -  -------- (response-Phi)
    %                       1 + m
    %  where:  
    %  x_n is the amplitude of the stimulation during the previous trial;
    %  Zn is set to 1 if the participant perceived an IoM (i.e. responded ‘Yes’) or 0 if he/she did not report any sensation (i.e. responded ‘No’);
    %  m is the number of reversals (how many times from the first trial of the staircase to the current one, the answer, Zn , switches from ‘Yes’ to ‘No’ and vice versa);
    %  Phi is the target threshold probability;
    %  c is a suitable constant (chosen through pilot experiments to be 0.4).
    % 
    % Proporties:
    %  Required:
    %  
    %   x_1: initial value of x_n
    %   c: constant
    %   Phi: target probability
    %   
    %   Example : sas = AHALAB_SAS(Phi, c, x_1) 
    %  
    %   
    %  Methods:
    %   reset(): reset the object to the initial state.
    %   update(response): update the object with the response of the observer.
    %   setUpdateFunction(f): set the functions used in the object to f.
    %   
    %   Example: sas.update(1); % for a postive response
    %            sas.update(0); % for a negative response 
    %  
    %  Optional args:
    %  
    %  xMax: maximum possible stimulation value.   default: inf
    %  xMin: minimum possible stimulation value.   default: -inf
    %  minStepSizeDown: lower bound for step size. default: -inf
    %  minStepSizeUp: upper bound for step size    default: inf
    %  stopCriterion: stop criterion               default: 'trials'
    %  stopRule: stop rule                         default: 50
    %  
    %  Exmaple: sas = AHALAB_SAS(Phi, c, x_1, 'minStepSizeDown', 5, 'minStepSizeUp', 5);
    %  
    %  outputs:
    %  
    %  m: number of reversals
    %  xStaircase: staircase values.
    %  reversals: binary array indicating reversals.
    %  responses: binary array indicating responses.
    %  trialCount: if stop is false, it is the numberr of the next trial. if stop is true, it is the number of trials run.
    %  stop: stop flag. true if the stop criterion is met.
    %  updateFunction : the function used to update the x_n value.
    % 
    %  Created by: Waleed Alghilan Oct-2023 (Aritificial Hands Area in Scuola Superiore Santanna)
    % 

    properties (SetAccess = private)
        m % number of reversals
        c % constant
        Phi % target probability
        xStaircase % staircase values
        reversals  % binary array indicating reversals
        responses % binary array indicating responses
        trialCount % the trialNumber 
        x_1 %initial value
        xMax % maximum value
        xMin % minimum value
        minStepSizeDown % lower bound for step size
        minStepSizeUp % upper bound for step size
        stopCriterion % stop criterion
        stopRule       % stop rule
        stop % stop flag 
        truncate
        roundOutput % round the output (example 2.3 -> 2; 2.7 -> 3)
        x
        xCurrent
        updateFunction % the function used to update the x_n value.
    end
    
    methods
        function obj = AHALAB_SAS(varargin)
            if nargin == 0
                obj.m = 0;
                obj.c = 0;
                obj.Phi = 0.85;
                obj.xStaircase = nan(51,1);
                obj.reversals = zeros(50,1);
                obj.responses = zeros(50,1);
                obj.minStepSizeDown = 0;
                obj.minStepSizeUp = 0;
                obj.trialCount =1;
            elseif nargin >= 3
                % check that the first 3 arguments are numeric
                if ~isnumeric(varargin{1}) || ~isnumeric(varargin{2}) || ~isnumeric(varargin{3})
                    error('AHALAB_SAS:invalidNumArgument','First three arguments must be numeric')
                end
                % check that Phi is between 0 and 1
                if varargin{1} < 0 || varargin{1} > 1
                    error('AHALAB_SAS:invalidPhi','Phi must be between 0 and 1')
                end

                obj.Phi = varargin{1};
                obj.c = varargin{2};
                obj.x_1 = varargin{3};
                % initialize values
                obj.initializeParams();
                % set the update function
                obj.updateFunction = @(phi,c,m, response) c*(response-phi)/(1+m); % default
                % check the added options
                NumOpts = nargin-3;
                for n = 3+1:2:nargin-mod(NumOpts,2)
                    valid = 0;
                    
                    if strcmpi(varargin{n},'minStepSizeDown')
                        obj.minStepSizeDown = -varargin{n+1};
                        valid = 1;
                    end
                    if strcmpi(varargin{n},'minStepSizeUp')
                        obj.minStepSizeUp = varargin{n+1};
                        valid = 1;
                    end
                    
                    if strcmpi(varargin{n}, 'StopCriterion')
                        obj.stopCriterion = varargin{n+1};
                        valid = 1;
                    end
                    if strcmpi(varargin{n}, 'StopRule')
                        obj.stopRule = varargin{n+1};
                        valid = 1;
                    end

                    if strcmpi(varargin{n}, 'StartValue')
                        obj.x_1 = varargin{n+1};
                        valid = 1;
                    end
                    if strcmpi(varargin{n}, 'xMax')
                        obj.xMax = varargin{n+1};
                        valid = 1;
                    end
                    if strcmpi(varargin{n}, 'xMin')
                        obj.xMin = varargin{n+1};
                        valid = 1;
                    end
                    if strcmpi(varargin{n}, 'Truncate')
                        obj.truncate = varargin{n+1};
                        valid = 1;
                    end
                    if strcmpi(varargin{n}, 'RoundOutput')
                        obj.roundOutput = varargin{n+1};
                        valid = 1;
                    end
                    if valid == 0
                        warning('AHALAB_SAS:invalidOption','%s is not a valid option. Ignored.',varargin{n})        
                    end        
                end            
            end
            
            obj.x = (max(min(obj.x_1,obj.xMax),obj.xMin));
            obj.xCurrent = obj.x;
            if(obj.truncate)
                obj.xStaircase = obj.x;
            else
                obj.xStaircase = obj.x_1;
            end

            
        end
        
        function obj = update(obj, response)
            % check response input is valid, if not it do nothing and quit
            if ~(response == 0 || response == 1 || response == true || response == false)
                message('AHALAB_SAS:invalidResponse','Response must be true, false, 0, 1')
                return
            end
            
            
            prev_i = max(obj.trialCount-1,1);
            
            % record response
            obj.responses(obj.trialCount) = response;
            
            % detect reversals
            if (obj.responses(obj.trialCount) ~= obj.responses(prev_i))
                obj.reversals(obj.trialCount) = 1;
            else
                obj.reversals(obj.trialCount) = 0;
            end
            
            % number of reversals
            obj.m = sum(obj.reversals);
            
            % calculate the step size
            
            % stairCase_step = obj.c*(response-obj.Phi)/(1+obj.m) ;
            stairCase_step = obj.updateFunction(obj.Phi, obj.c, obj.m, response);
            % minimum step size 
            stairCase_step = min(max(-stairCase_step,obj.minStepSizeDown),obj.minStepSizeUp);
            
            if(obj.roundOutput)
                stairCase_step = round(stairCase_step);
            end
            
            % x_nplus1 = x_n - c*(response-Phi)/(1+m)
            xCurrentRaw = obj.xStaircase(obj.trialCount) - stairCase_step;
            
            obj.x(obj.trialCount+1) = (max(min(xCurrentRaw,obj.xMax),obj.xMin)); % this is what is sent in the next step
            
            % When set to ‘ no /false / 0 ’:
            % up/down rule will be applied to stimulus intensities [untruncated] by xMax and xMin
            % (but stimulus intensities assigned to sas.xCurrent will be truncated by xMax and xMin).
            % check Psychophysics by FREDERICK A.A. KIGNDOM and NICOLAAS PINS for more information.
            if(obj.truncate)
                obj.xStaircase(obj.trialCount+1) = obj.x(obj.trialCount+1);
            else
                obj.xStaircase(obj.trialCount+1) = xCurrentRaw;
            end
            
            % stop criterion
            if strncmpi(obj.stopCriterion,'reversals',4) && sum(obj.reversals) == obj.stopRule
                obj.stop = true;
            end
            if strncmpi(obj.stopCriterion,'trials',4) && obj.trialCount == obj.stopRule
                obj.stop = true;
            end
            
            if(~obj.stop)
                obj.xCurrent = obj.x(obj.trialCount+1);
                obj.trialCount = obj.trialCount+1;
            else
                obj.xCurrent = [];
                obj.trialCount = obj.trialCount;
            end
        end

        function obj = initializeParams(obj)
                obj.xStaircase = obj.x_1;
                obj.xCurrent = obj.x_1;
                obj.x(1)=obj.x_1;
                obj.m = 0;% number of reversals
                obj.reversals = []; % binary array indicating reversals
                obj.responses = [];% binary array indicating responses
                obj.trialCount = 1; % the trialNumber
                obj.xMax = inf; % maximum value
                obj.xMin = -inf;% minimum value
                obj.minStepSizeDown = -inf; % lower bound for step size
                obj.minStepSizeUp = inf;% upper bound for step size
                obj.stopCriterion = "trials"; % stop criterion
                obj.stopRule      = 50;   % stop rule
                obj.stop          = false;% stop flag 
                obj.truncate      = true;
                obj.roundOutput   = true; % round the output (example 2.3 -> 2; 2.7 -> 3)
        end
        
        function obj = reset(obj)
                obj.xStaircase = obj.x_1;
                obj.xCurrent = obj.x_1;
                obj.x=obj.x_1;
                obj.m = 0;
                obj.reversals = []; 
                obj.responses = [];
                obj.trialCount = 1; 
                obj.stop = false;
        end

        function obj = backstep(obj,varargin)
            % deletes the last n trials
            
            if (nargin == 2 && isnumeric(varargin{1}))
               nDeletes = varargin{1}; 
            end
            if(nargin == 1)
                nDeletes = 1;
            end
            if(nDeletes>=obj.trialCount)
                warning('AHALAB_SAS:invalidInput'," the number of deleted trials,exceeds the number of trials. Ignored")
                return;
            end

            if(obj.stop)
                % because trialCount stops incrementing if exeperiment finished
                rangeStartForX = obj.trialCount-nDeletes+2;
                rangeStartForResponses = obj.trialCount-nDeletes+1;
                obj.trialCount = obj.trialCount-nDeletes+1;
                obj.stop = 0;

            elseif(obj.trialCount>=2)
                rangeStartForX = obj.trialCount-nDeletes+1;
                rangeStartForResponses = obj.trialCount-nDeletes+1;
                obj.trialCount = obj.trialCount-nDeletes;
            end
            
            if(obj.trialCount>=2)
                obj.xStaircase(rangeStartForX:end) = [];
                obj.x(rangeStartForX:end) = [];
                obj.xCurrent = obj.x(end);
                obj.m = obj.m - sum(obj.reversals(rangeStartForResponses:end));
                obj.reversals(rangeStartForResponses:end) = [];
                obj.responses(rangeStartForResponses :end) = [];
            else
                % special case only one is present -> reset everything
                obj.xStaircase = obj.x_1;
                obj.x = obj.x_1;
                obj.xCurrent = obj.x_1;
                obj.m = 0;
                obj.reversals =[];
                obj.responses = [];
            end
        end

        function obj = setFunction(obj, func)
            % Change the update function of the object.
            % the function handle must have 4 inputs in this order (phi,c,m, response)
            % example:
            %   custom_updateFunction = @(phi,c,m, response) c*(response-Phi)/(2+m);
            %   sas.setFunction(custom_updateFunction);
           
            if( ~isa(func, 'function_handle'))
                % check that the function has 4 inputs
                warning('AHALAB_SAS:invalidFunction','The input is not a function handle. Ignored.')
                return
            end
            if( nargin(func) ~= 4)
                warning('AHALAB_SAS:invalidFunction','The update function must have 4 inputs (phi,c,m, response). Ignored.') 
                return;
            end
            obj.updateFunction = func;
        end


    end
end