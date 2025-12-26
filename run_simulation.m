function results = run_simulation(cfg)
% RUN_SIMULATION: 메인 시뮬레이션 실행 함수
%
% 사용법:
%   results = run_simulation();           % 기본 설정으로 실행
%   results = run_simulation(cfg);        % 사용자 설정으로 실행
%
% 입력:
%   cfg - 설정 구조체 (선택, 없으면 config_default 사용)
%
% 출력:
%   results - 시뮬레이션 결과 구조체

    %% ═══════════════════════════════════════════════════
    %  1. 설정 로드
    %  ═══════════════════════════════════════════════════
    
    if nargin < 1 || isempty(cfg)
        cfg = config_default();
    end
    
    % 설정 검증
    cfg = validate_config(cfg);
    
    %% ═══════════════════════════════════════════════════
    %  2. 시뮬레이터 초기화
    %  ═══════════════════════════════════════════════════
    
    if cfg.verbose >= 1
        print_header(cfg);
        tic;
    end
    
    % 시뮬레이터 인스턴스 생성
    sim = Simulator(cfg);
    
    %% ═══════════════════════════════════════════════════
    %  3. 시뮬레이션 실행
    %  ═══════════════════════════════════════════════════
    
    results = sim.run();
    
    %% ═══════════════════════════════════════════════════
    %  4. 결과 출력
    %  ═══════════════════════════════════════════════════
    
    if cfg.verbose >= 1
        elapsed = toc;
        results.elapsed_real_time = elapsed;
        print_results(results, cfg, elapsed);
    end
end

%% =========================================================================
%  Helper Functions
%  =========================================================================

function cfg = validate_config(cfg)
% VALIDATE_CONFIG: 설정 검증 및 파생값 계산

    % 필수 필드 확인
    required_fields = {'simulation_time', 'num_stas', 'num_ru_ra', 'slot_duration'};
    for i = 1:length(required_fields)
        if ~isfield(cfg, required_fields{i})
            error('필수 설정 누락: %s', required_fields{i});
        end
    end
    
    % 파생값 계산
    cfg.total_slots = ceil(cfg.simulation_time / cfg.slot_duration);
    cfg.warmup_slots = ceil(cfg.warmup_time / cfg.slot_duration);
    
    % T_hold 슬롯 변환
    if cfg.thold_enabled
        cfg.thold_slots = ceil(cfg.thold_value / cfg.slot_duration);
    else
        cfg.thold_slots = 0;
    end
end

function print_header(cfg)
% PRINT_HEADER: 시뮬레이션 시작 헤더 출력

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║     WiFi 6 T_hold Simulator (Time-Slot Based)                ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    fprintf('[설정]\n');
    fprintf('  시뮬레이션 시간: %.1f초 (워밍업: %.1f초)\n', ...
        cfg.simulation_time, cfg.warmup_time);
    fprintf('  총 슬롯 수: %d (워밍업: %d)\n', cfg.total_slots, cfg.warmup_slots);
    fprintf('  TF 주기: %d 슬롯 (%.1f μs)\n', cfg.frame_exchange_slots, ...
        cfg.frame_exchange_slots * cfg.slot_duration * 1e6);
    fprintf('  예상 TF 수: %d회\n', ceil(cfg.total_slots / cfg.frame_exchange_slots));
    fprintf('  STA 수: %d\n', cfg.num_stas);
    fprintf('  RA-RU: %d, SA-RU: %d\n', cfg.num_ru_ra, cfg.num_ru_sa);
    fprintf('  OCW: [%d, %d]\n', cfg.ocw_min, cfg.ocw_max);
    
    fprintf('\n[T_hold]\n');
    if cfg.thold_enabled
        fprintf('  활성화: Yes\n');
        fprintf('  T_hold 값: %.3f초 (%d 슬롯)\n', cfg.thold_value, cfg.thold_slots);
        fprintf('  정책: %s\n', cfg.thold_policy);
    else
        fprintf('  활성화: No\n');
    end
    
    fprintf('\n[트래픽]\n');
    fprintf('  모델: %s\n', cfg.traffic_model);
    if strcmp(cfg.traffic_model, 'pareto_onoff')
        rho = cfg.mu_on / (cfg.mu_on + cfg.mu_off);
        fprintf('  Alpha: %.2f\n', cfg.pareto_alpha);
        fprintf('  On/Off: %.3f/%.3f초 (ρ=%.2f)\n', cfg.mu_on, cfg.mu_off, rho);
        fprintf('  Lambda: %.1f pkt/s\n', cfg.lambda);
    end
    
    fprintf('\n[시뮬레이션 시작]\n');
end

function print_results(results, cfg, elapsed)
% PRINT_RESULTS: 결과 요약 출력

    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════╗\n');
    fprintf('║                     시뮬레이션 결과                           ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
    
    fprintf('[실행 정보]\n');
    fprintf('  실제 소요 시간: %.2f초\n', elapsed);
    fprintf('  시뮬레이션 시간: %.2f초\n', cfg.simulation_time);
    fprintf('  가속비: %.1fx\n', cfg.simulation_time / elapsed);
    fprintf('  처리된 TF 주기: %d회\n', results.tf_count);
    
    fprintf('\n[패킷 통계]\n');
    fprintf('  생성: %d개\n', results.packets.generated);
    fprintf('  완료: %d개\n', results.packets.completed);
    fprintf('  완료율: %.1f%%\n', results.packets.completion_rate * 100);
    
    fprintf('\n[지연 (ms)]\n');
    fprintf('  평균: %.4f\n', results.delay.mean_ms);
    fprintf('  P90: %.4f\n', results.delay.p90_ms);
    fprintf('  P99: %.4f\n', results.delay.p99_ms);
    fprintf('  최대: %.4f\n', results.delay.max_ms);
    
    fprintf('\n[처리율]\n');
    fprintf('  총 처리율: %.2f Mbps\n', results.throughput.total_mbps);
    fprintf('  채널 이용률: %.1f%%\n', results.throughput.channel_utilization * 100);
    
    fprintf('\n[RU 활용률]\n');
    fprintf('  RA-RU 활용률: %.1f%% (성공: %.1f%%)\n', ...
        results.ru_utilization.ra_utilization * 100, ...
        results.ru_utilization.ra_success_util * 100);
    fprintf('  SA-RU 활용률: %.1f%%\n', results.ru_utilization.sa_utilization * 100);
    fprintf('  전체 RU 활용률: %.1f%% (성공: %.1f%%)\n', ...
        results.ru_utilization.total_utilization * 100, ...
        results.ru_utilization.total_success_util * 100);
    
    fprintf('\n[UORA (RA-RU)]\n');
    fprintf('  성공률: %.2f%%\n', results.uora.success_rate * 100);
    fprintf('  충돌률: %.2f%%\n', results.uora.collision_rate * 100);
    fprintf('  유휴률: %.2f%%\n', results.uora.idle_rate * 100);
    
    fprintf('\n[BSR]\n');
    fprintf('  Explicit: %d회\n', results.bsr.explicit_count);
    fprintf('  Implicit: %d회\n', results.bsr.implicit_count);
    fprintf('  Explicit 비율: %.1f%%\n', results.bsr.explicit_ratio * 100);
    
    if cfg.thold_enabled
        fprintf('\n[T_hold]\n');
        fprintf('  발동 횟수: %d회\n', results.thold.activations);
        fprintf('  Hit (패킷 도착): %d회\n', results.thold.hits);
        fprintf('  Hit Rate: %.1f%%\n', results.thold.hit_rate * 100);
        fprintf('  UORA 회피: %d회\n', results.thold.uora_avoided);
    end
    
    fprintf('\n[공정성]\n');
    fprintf('  Jain Index: %.4f\n', results.fairness.jain_index);
    
    fprintf('\n════════════════════════════════════════════════════════════════\n\n');
end
