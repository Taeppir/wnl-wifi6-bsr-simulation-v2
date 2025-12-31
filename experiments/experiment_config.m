function base_cfg = experiment_config()
% EXPERIMENT_CONFIG: T_hold 실험용 공통 설정
%
% 출력: base_cfg - 기본 설정 구조체

    % 기본 설정 로드
    base_cfg = config_default();
    
    % 실험용 값 덮어쓰기
    base_cfg.simulation_time = 30;      % 30초
    base_cfg.warmup_time = 5;           % 5초 워밍업
    base_cfg.mu_on = 0.050;             % 50ms
    base_cfg.mpdu_size = 2000;          % 2000 bytes
    base_cfg.max_packets = 200000;
    base_cfg.verbose = 0;               % 출력 최소화
    base_cfg.seed = 42;                 % 재현성
end
