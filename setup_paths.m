function setup_paths()
% SETUP_PATHS: MATLAB 경로 설정
%
% 사용법:
%   setup_paths();

    % 현재 스크립트 위치를 기준으로 루트 디렉토리 설정
    script_path = fileparts(mfilename('fullpath'));
    
    if isempty(script_path)
        script_path = pwd;
    end
    
    % 모든 하위 디렉토리 추가
    subdirs = {
        'config'
        'core'
        'entities'
        'mechanisms'
        'mechanisms/bsr'
        'mechanisms/thold'
        'mechanisms/uora'
        'traffic'
        'metrics'
        'experiments'
        'experiments/scripts'
        'experiments/analysis'
        'utils'
        'tests'
    };
    
    for i = 1:length(subdirs)
        full_path = fullfile(script_path, subdirs{i});
        if exist(full_path, 'dir')
            addpath(full_path);
        end
    end
    
    fprintf('WiFi 6 T_hold Simulator 경로 설정 완료\n');
    fprintf('루트 디렉토리: %s\n', script_path);
end
