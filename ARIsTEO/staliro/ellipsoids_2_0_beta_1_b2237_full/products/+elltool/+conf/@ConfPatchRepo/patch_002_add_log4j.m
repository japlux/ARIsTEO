% Copyright Claudio Menghi, University of Luxembourg, 2018-2019, claudio.menghi@uni.lu  
function SInput=patch_002_add_log4j(~,SInput)
    if(~isfield(SInput, 'logging'))
        SInput.logging = struct;
    end
    if(~isfield(SInput.logging, 'log4jSettings'))
        % monstrous format string to have good indentation in settings
        SInput.logging.log4jSettings = ...
            sprintf(strcat('\n\t\t\t%s\n\t\t\t%s\n\t\t\t%s',...
                    '\n\t\t\t%s\n\t\t\t%s\n\t\t\t%s',...
                    '\n\t\t\t%s\n\t\t\t%s',...
                    '\n\t\t\t%s\n\t\t\t%s\n\t\t\t%s\n\t\t\t%s',...
                    '\n\t\t\t%s\n\t\t\t%s\n\t\t'),...
                'log4j.rootLogger=INFO, stdout',...
                'log4j.logger.elltool.reach = INFO, A1',...
                'log4j.additivity.elltool.reach = TRUE',...
                'log4j.logger.gras.ellapx = INFO, A1',...
			    'log4j.additivity.gras.ellapx = TRUE',...
                'log4j.appender.stdout=org.apache.log4j.ConsoleAppender',...
                'log4j.appender.stdout.layout=org.apache.log4j.PatternLayout',...
                'log4j.appender.stdout.layout.ConversionPattern=%5p %c - %m\n',...
                'log4j.appender.A1=org.apache.log4j.FileAppender',...
                '#do not change - name of the main log file should have a',...
                '#fixed pattern so that email logger can pick it up',...
                'log4j.appender.A1.File=${elltool.log4j.logfile.dirwithsep}${elltool.log4j.logfile.main.name}',...
                'log4j.appender.A1.layout=org.apache.log4j.PatternLayout',...
                'log4j.appender.A1.layout.ConversionPattern=%d %5p %c - %m%n');
    end
end