function cfg = config_default()
% CONFIG_DEFAULT: 기본 시뮬레이션 설정 (Table 1 기준)
%
% 출력:
%   cfg - 설정 구조체

    %% ═══════════════════════════════════════════════════
    %  시뮬레이션 제어
    %  ═══════════════════════════════════════════════════
    
    cfg.simulation_time = 30.0;      % 시뮬레이션 시간 (초)
    cfg.warmup_time = 0.0;           % 워밍업 시간 (초)
    cfg.verbose = 1;                 % 출력 레벨 (0: 없음, 1: 기본, 2: 상세)
    cfg.seed = 1234;                 % 랜덤 시드
    
    %% ═══════════════════════════════════════════════════
    %  PHY 파라미터 (IEEE 802.11ax, Table 1)
    %  ═══════════════════════════════════════════════════
    
    cfg.slot_duration = 9e-6;        % 슬롯 길이 (9 μs)
    cfg.sifs = 16e-6;                % SIFS (16 μs)
    cfg.bandwidth = 20;              % 대역폭 (MHz)
    
    % RU 구성 (20MHz -> 9 RUs with 26-tone)
    cfg.num_ru_total = 9;
    cfg.num_ru_ra = 1;
    cfg.num_ru_sa = cfg.num_ru_total - cfg.num_ru_ra;
    
    % 프레임 길이
    cfg.len_phy_header = 40e-6;      % PHY 헤더 (40 μs)
    cfg.len_trigger_frame = 100e-6;  % Trigger Frame (100 μs)
    cfg.len_mu_back = 68e-6;         % MU-BACK (68 μs)
    
    %% ═══════════════════════════════════════════════════
    %  MAC 파라미터
    %  ═══════════════════════════════════════════════════
    
    cfg.num_stas = 20;               % STA 수
    cfg.ocw_min = 7;                 % OCW 최소값
    cfg.ocw_max = 31;                % OCW 최대값
    cfg.mpdu_size = 2000;            % MPDU 크기 (bytes)
    
    % 데이터 전송률 (Table 1: 64-QAM 2/3, 26-tone RU)
    % 계산: (24 subcarriers × 6 bits × 2/3) / 14.4μs = 6.67 Mb/s
    cfg.data_rate_per_ru = 6.67e6;   % 6.67 Mb/s per RU
    
    %% ═══════════════════════════════════════════════════
    %  T_hold 설정
    %  ═══════════════════════════════════════════════════
    
    cfg.thold_enabled = true;        % T_hold 활성화
    cfg.thold_value = 0.010;         % T_hold 값 (10 ms)
    cfg.thold_policy = 'fixed';      % 정책: 'fixed' | 'adaptive'
    
    %% ═══════════════════════════════════════════════════
    %  트래픽 설정
    %  ═══════════════════════════════════════════════════
    
    % 트래픽 모델: 'saturated' | 'poisson' | 'pareto_onoff'
    cfg.traffic_model = 'pareto_onoff';
    
    % Pareto On/Off 파라미터
    cfg.pareto_alpha = 1.5;          % Shape parameter (α > 1)
    cfg.mu_on = 0.05;                % On 기간 평균 (초)
    cfg.rho = 0.5;                   % Duty cycle (On 비율)
    cfg.mu_off = cfg.mu_on * (1 - cfg.rho) / cfg.rho;  % 자동 계산
    cfg.lambda = 100;                % On 기간 중 패킷 도착률 (pkt/s)
    
    %% ═══════════════════════════════════════════════════
    %  메트릭 수집 설정
    %  ═══════════════════════════════════════════════════
    
    cfg.max_packets = 1000000;       % 최대 추적 패킷 수
    cfg.collect_per_sta = true;      % STA별 메트릭 수집
    cfg.collect_trace = false;       % 상세 트레이스 수집 (디버깅용)
    
    %% ═══════════════════════════════════════════════════
    %  파생값 계산
    %  ═══════════════════════════════════════════════════
    
    % 슬롯 변환 (validate_config에서 재계산됨)
    cfg.total_slots = 0;
    cfg.warmup_slots = 0;
    cfg.thold_slots = 0;
    
    % 프레임 길이 (슬롯 단위)
    cfg.len_phy_header_slots = ceil(cfg.len_phy_header / cfg.slot_duration);
    cfg.len_tf_slots = ceil(cfg.len_trigger_frame / cfg.slot_duration);
    cfg.len_mu_back_slots = ceil(cfg.len_mu_back / cfg.slot_duration);
    cfg.sifs_slots = ceil(cfg.sifs / cfg.slot_duration);
    
    % 데이터 전송 슬롯 (MPDU 기준)
    data_tx_time = (cfg.mpdu_size * 8) / cfg.data_rate_per_ru;
    cfg.data_tx_slots = ceil(data_tx_time / cfg.slot_duration);
    
    % TF 주기 계산: [PHY+TF] + SIFS + [PHY+DATA] + SIFS + [PHY+BA] + SIFS
    cfg.frame_exchange_slots = cfg.len_phy_header_slots + cfg.len_tf_slots + ...
                               cfg.sifs_slots + ...
                               cfg.len_phy_header_slots + cfg.data_tx_slots + ...
                               cfg.sifs_slots + ...
                               cfg.len_phy_header_slots + cfg.len_mu_back_slots + ...
                               cfg.sifs_slots;
end