classdef ESA_Spectrum_Analyzer < handle
    %ESA_SPECTRUM_ANALYZER Class definition for handling communication with
    %the HP/Agilent/Keysight ESA Spectrum Analyzer

    properties
        conn                %The GPIB connection
        gpib_driver         %GPIB driver
        gpib_board          %GPIB board index
        gpib_address        %GPIB primary address
    end

    properties(Constant)
        DEFAULT_DRIVER = 'ni';
    end


    methods
        function self = ESA_Spectrum_Analyzer(varargin)
            %ESA_SPECTRUM_ANALYZER Creates an object of this class
            %
            %   SELF = ESA_SPECTRUM_ANALYZER(BOARD_INDEX,PRIMARY_ADDRESS)
            %   Sets the GPIB communication properties to use the given
            %   board index and primary address.  Vendor driver defaults to
            %   DEFAULT_DRIVER
            %
            %   SELF = ESA_SPECTRUM_ANALYZER(DRIVER,__) Uses given device
            %   driver along with board index and primary address
            if nargin == 0
                error('You must supply at least a board index and primary address!');
            end
            self.set_gpib_properties(varargin{:});
        end

        function self = set_gpib_properties(self,varargin)
            %SET_GPIB_PROPERTIES Sets GPIB properties
            %
            %   SELF = SET_GPIB_PROPERTIES(SELF,BOARD_INDEX,PRIMARY_ADDRESS)
            %   Sets the GPIB communication properties to use the given
            %   board index and primary address.  Vendor driver defaults to
            %   DEFAULT_DRIVER
            %
            %   SELF = SET_GPIB_PROPERTIES(SELF,DRIVER,__) Uses given device
            %   driver along with board index and primary address
            if numel(varargin) == 2
                self.gpib_driver = self.DEFAULT_DRIVER;
                self.gpib_board = varargin{1};
                self.gpib_address = varargin{2};
            elseif numel(varargin) == 3
                self.gpib_driver = varargin{1};
                self.gpib_board = varargin{2};
                self.gpib_address = varargin{3};
            end
        end

        function self = open(self,varargin)
            %OPEN Creates and opens a GPIB communication object
            %
            %   SELF = OPEN(SELF,VARARGIN) VARARGIN here is the same
            %   argument list as for SET_GPIB_PROPERTIES
            self.set_gpib_properties(varargin{:});

            if isempty(self.conn) || ~isvalid(obj)
                gpib_device = self.find_device();
                if isempty(gpib_device)
                    self.conn = gpib(self.gpib_driver,self.gpib_board,self.gpib_address);
                else
                    self.conn = gpib_device;
                end
            end

            if ~self.isopen()
                self.InputBufferSize = 2^20;
                fopen(self.conn);
            end
        end

        function self = close(self)
            %CLOSE Closes and deletes the GPIB communication object
            if self.isopen()
                fclose(self.conn);
            end
            if isvalid(self.conn)
                delete(self.conn);
            end
            self.conn = [];
        end

        function delete(self)
            %DELETE Hook when object is cleared. Deletes GPIB communication
            %object
            self.close;
        end

        function gpib_device = find_device(self)
            %FIND_DEVICE Finds the GPIB device corresponding to this
            %objects GPIB properties
            gpib_device = instrfindall('type','gpib','BoardIndex',self.gpib_board,'PrimaryAddress',self.gpib_address);
        end

        function r = isopen(self)
            %ISOPEN Returns true if the GPIB communication object is open,
            %false otherwise
            r = strcmpi(self.conn.Status,'open');
        end

        function self = cmd(self,s,varargin)
            %CMD Sends a command to the device but does not query the
            %response
            %
            %   SELF = CMD(SELF,S) Sends the string command to the device.
            %   S does not need to be terminated with LF
            s = sprintf(s,varargin{:});
            s = regexprep(s,'\n$','');
            fprintf(self.conn,'%s\n',s);
        end

        function r = ask(self,s)
            %ASK Sends a command to the device and queries the response
            %
            %   R = ASK(SELF,S) Sends the string command to the device.
            %   S does not need to terminated with LF. Returns string
            %   response R.
            self.cmd(s);
            r = fscanf(self.conn);
        end

        function self = set_center_frequency(self,freq)
            %SET_CENTER_FREQUENCY Sets the center frequency
            %
            %   SELF = SET_CENTER_FREQUENCY(SELF,FREQ) Sets the center
            %   frequency to FREQ in Hz
            self.cmd(':freq:cent %.9e',freq);
        end

        function freq = get_center_frequency(self)
            %GET_CENTER_FREQUENCY Gets the center frequency
            %
            %   FREQ = GET_CENTER_FREQUENCY(SELF) Gets the center
            %   frequency FREQ in Hz
            freq = sscanf(self.ask(':freq:cent?'),'%e');
        end

        function self = set_span(self,span)
            %SET_SPAN Sets the frequency span
            %
            %   SELF = SET_SPAN(SELF,SPAN) Sets the frequency span to SPAN
            %   in HZ
            self.cmd(':freq:span %.9e',span);
        end

        function freq = get_span(self)
            %GET_SPAN Gets the frequency span
            %
            %   SPAN = GET_SPAN(SELF) Gets the frequency span SPAN in Hz
            freq = sscanf(self.ask(':freq:span?'),'%e');
        end

        function self = set_bandwidth(self,bandwidth)
            %SET_BANDWIDTH Sets the resolution bandwidth
            %
            %   SELF = SET_BANDWIDTH(SELF,BANDWIDTH) Sets the resolution
            %   bandwidth to BANDWIDTH in Hz
            self.cmd(':band:res %.0f',bandwidth);
        end

        function bandwidth = get_bandwidth(self)
            %GET_BANDWIDTH Gets the resolution bandwidth
            %
            %   BANDWIDTH = GET_BANDWIDTH(SELF) Gets the resolution
            %   bandwidth BANDWIDTH in Hz
            bandwidth = sscanf(self.ask(':band:res?'),'%e');
        end

        function self = set_marker_x(self,x)
            %SET_MARKER_X Sets marker 1 to a frequency value
            %
            %   SELF = SET_MARKER_X(SELF,X) Sets the X position of marker 1
            %   to frequency X
            self.cmd(':calc:mark1:x %.9e',x);
        end

        function x = get_marker_x(self)
            %GET_MARKER_X Gets marker 1's frequency value
            %
            %   X = GET_MARKER_X(SELF) Gets the X position of marker 1
            %   as frequency X
            x = sscanf(self.ask(':calc:mark1:x?'),'%e');
        end

        function y = get_marker_y(self)
            %GET_MARKER_Y Gets marker 1's amplitude value
            %
            %   Y = GET_MARKER_Y(SELF) Gets the Y value of marker 1 as an
            %   amplitude
            y = sscanf(self.ask(':calc:mark1:y?'),'%e');
        end

        function [f,P] = get_trace(self)
            %GET_TRACE Returns the current trace
            %
            %   [F,P] = GET_TRACE(SELF) returns frequency and power vectors
            %   F and P
            center_frequency = self.get_center_frequency();
            span = self.get_span();
            
            P = sscanf(self.cmd(':TRACE:DATA? RAWTRACE'),'%e,',[1,Inf]);
            f = center_frequency + span/2*linspace(-1,1,numel(P));
        end

    end

end