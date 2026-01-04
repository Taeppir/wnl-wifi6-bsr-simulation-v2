%% verify_simulator.m
% ═══════════════════════════════════════════════════════════════════════════
% 시뮬레이터 검증 스크립트
% ═══════════════════════════════════════════════════════════════════════════
%
% 본 실험 전 필수 검증 항목:
%   1. 시스템 용량 검증 (Poisson 과부하 → throughput ≈ 이론 용량)
%   2. Baseline 검증 (T_hold=0이면 thold_enabled=false와 동일)
%   3. 트래픽 모델 검증 (mu_on, mu_off 통계가 설정값과 일치)
%
% 사용법:
%   cd('wnl-wifi6-bsr-simulation-v2-main')
%   setup_paths
%   verify_simulator
%
% ═══════════════════════════════════════════════════════════════════════════

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║            시뮬레이터 검증 (Pre-Experiment Validation)             ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

% %% ═══════════════════════════════════════════════════════════════════════════
% %  검증 1: 시스템 용량 (System Capacity)
% %  ═══════════════════════════════════════════════════════════════════════════
% fprintf('═══════════════════════════════════════════════════════════════════\n');
% fprintf('검증 1: 시스템 용량 (Poisson Saturation Test)\n');
% fprintf('═══════════════════════════════════════════════════════════════════\n\n');

% % 이론값 계산
% cfg_base = config_default();
% cfg_base.verbose = 0;

% % TF 주기 (슬롯)
% tf_period_slots = cfg_base.frame_exchange_slots;
% tf_period_sec = tf_period_slots * cfg_base.slot_duration;
% tf_per_sec = 1 / tf_period_sec;

% % 시스템 용량 계산
% % SA-RU만 사용 (RA-RU는 경쟁 접속용)
% capacity_pkt_per_sec = tf_per_sec * cfg_base.num_ru_sa;
% capacity_mbps = capacity_pkt_per_sec * cfg_base.mpdu_size * 8 / 1e6;

% fprintf('[이론값 계산]\n');
% fprintf('  TF 주기: %d 슬롯 (%.3f ms)\n', tf_period_slots, tf_period_sec * 1000);
% fprintf('  TF/초: %.2f\n', tf_per_sec);
% fprintf('  SA-RU 개수: %d\n', cfg_base.num_ru_sa);
% fprintf('  시스템 용량: %.1f pkt/s (%.2f Mbps)\n\n', capacity_pkt_per_sec, capacity_mbps);

% % Poisson 과부하 테스트
% fprintf('[Poisson 과부하 테스트]\n');
% cfg_poisson = config_default();
% cfg_poisson.traffic_model = 'poisson';
% cfg_poisson.poisson_rate = 200;          % pkt/s/STA (과부하)
% cfg_poisson.thold_enabled = false;        % T_hold 비활성화
% cfg_poisson.simulation_time = 20;
% cfg_poisson.seed = 1234;
% cfg_poisson.verbose = 0;

% total_arrival_rate = cfg_poisson.poisson_rate * cfg_poisson.num_stas;
% fprintf('  Poisson rate: %d pkt/s/STA\n', cfg_poisson.poisson_rate);
% fprintf('  총 도착률: %d pkt/s (용량의 %.1f%%)\n', ...
%     total_arrival_rate, total_arrival_rate / capacity_pkt_per_sec * 100);

% fprintf('\n  시뮬레이션 실행 중...\n');
% tic;
% result_poisson = run_simulation(cfg_poisson);
% elapsed = toc;
% fprintf('  완료 (%.2f초 소요)\n\n', elapsed);

% % 측정값 계산
% measured_throughput_pkt = result_poisson.packets.completed / cfg_poisson.simulation_time;
% measured_throughput_mbps = measured_throughput_pkt * cfg_poisson.mpdu_size * 8 / 1e6;
% capacity_error = abs(measured_throughput_pkt - capacity_pkt_per_sec) / capacity_pkt_per_sec * 100;

% fprintf('[결과 비교]\n');
% fprintf('  이론 용량:   %.1f pkt/s (%.2f Mbps)\n', capacity_pkt_per_sec, capacity_mbps);
% fprintf('  측정 용량:   %.1f pkt/s (%.2f Mbps)\n', measured_throughput_pkt, measured_throughput_mbps);
% fprintf('  오차:        %.2f%%\n', capacity_error);
% fprintf('  완료율:      %.1f%% (%.0f / %.0f)\n', ...
%     result_poisson.packets.completion_rate * 100, ...
%     result_poisson.packets.completed, ...
%     result_poisson.packets.generated);

% if capacity_error < 5
%     fprintf('  ✅ PASS: 오차 < 5%%\n\n');
%     test1_pass = true;
% else
%     fprintf('  ❌ FAIL: 오차 >= 5%%\n\n');
%     test1_pass = false;
% end


%% ═══════════════════════════════════════════════════════════════════════════
%  검증 2: Baseline 일관성 (T_hold=0 vs thold_enabled=false)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('═══════════════════════════════════════════════════════════════════\n');
fprintf('검증 2: Baseline 일관성 (T_hold=0 vs Disabled)\n');
fprintf('═══════════════════════════════════════════════════════════════════\n\n');

seed = 5678;  % 동일한 시드 사용

% Case A: T_hold enabled but value = 0
fprintf('[Case A: thold_enabled=true, thold_value=0]\n');
cfg_a = config_default();
cfg_a.thold_enabled = true;
cfg_a.thold_value = 0;
cfg_a.simulation_time = 10;
cfg_a.seed = seed;
cfg_a.verbose = 0;

result_a = run_simulation(cfg_a);
fprintf('  완료 패킷: %d\n', result_a.packets.completed);
fprintf('  평균 지연: %.4f ms\n', result_a.delay.mean_ms);

% Case B: T_hold disabled
fprintf('\n[Case B: thold_enabled=false]\n');
cfg_b = config_default();
cfg_b.thold_enabled = false;
cfg_b.simulation_time = 10;
cfg_b.seed = seed;
cfg_b.verbose = 0;

result_b = run_simulation(cfg_b);
fprintf('  완료 패킷: %d\n', result_b.packets.completed);
fprintf('  평균 지연: %.4f ms\n', result_b.delay.mean_ms);

% 비교
fprintf('\n[비교]\n');
pkt_diff = abs(result_a.packets.completed - result_b.packets.completed);
delay_diff = abs(result_a.delay.mean_ms - result_b.delay.mean_ms);
fprintf('  패킷 수 차이: %d\n', pkt_diff);
fprintf('  지연 차이: %.4f ms\n', delay_diff);

% 허용 오차: 완전 동일하거나 매우 작은 차이
if pkt_diff == 0 && delay_diff < 0.001
    fprintf('  ✅ PASS: 결과 완전 일치\n\n');
    test2_pass = true;
elseif pkt_diff <= 5 && delay_diff < 0.1
    fprintf('  ⚠️ WARN: 약간의 차이 (허용 범위 내)\n\n');
    test2_pass = true;
else
    fprintf('  ❌ FAIL: 결과 불일치\n\n');
    test2_pass = false;
end


% %% ═══════════════════════════════════════════════════════════════════════════
% %  검증 3: 트래픽 모델 검증 (Pareto On/Off 통계)
% %  ═══════════════════════════════════════════════════════════════════════════
% fprintf('═══════════════════════════════════════════════════════════════════\n');
% fprintf('검증 3: 트래픽 모델 (Pareto On/Off 통계)\n');
% fprintf('═══════════════════════════════════════════════════════════════════\n\n');

% % 설정값
% cfg_traffic = config_default();
% cfg_traffic.verbose = 0;

% target_mu_on = cfg_traffic.mu_on;
% target_mu_off = cfg_traffic.mu_off;
% target_alpha = cfg_traffic.pareto_alpha;
% target_rho = cfg_traffic.rho;

% fprintf('[설정값]\n');
% fprintf('  mu_on: %.3f초\n', target_mu_on);
% fprintf('  mu_off: %.3f초\n', target_mu_off);
% fprintf('  alpha: %.2f\n', target_alpha);
% fprintf('  rho (duty cycle): %.2f\n\n', target_rho);

% % Pareto 샘플링 테스트 (직접 샘플링)
% fprintf('[Pareto 샘플링 테스트]\n');
% n_samples = 10000;

% % Pareto 최소값 계산 (k = mu * (alpha-1) / alpha)
% k_on = target_mu_on * (target_alpha - 1) / target_alpha;
% k_off = target_mu_off * (target_alpha - 1) / target_alpha;

% % 샘플링
% on_samples = zeros(n_samples, 1);
% off_samples = zeros(n_samples, 1);

% for i = 1:n_samples
%     u = rand();
%     on_samples(i) = k_on / (u^(1/target_alpha));
%     u = rand();
%     off_samples(i) = k_off / (u^(1/target_alpha));
% end

% measured_mu_on = mean(on_samples);
% measured_mu_off = mean(off_samples);
% measured_rho = measured_mu_on / (measured_mu_on + measured_mu_off);

% fprintf('  On 기간 - 목표: %.3f초, 측정: %.3f초 (오차: %.1f%%)\n', ...
%     target_mu_on, measured_mu_on, abs(measured_mu_on - target_mu_on) / target_mu_on * 100);
% fprintf('  Off 기간 - 목표: %.3f초, 측정: %.3f초 (오차: %.1f%%)\n', ...
%     target_mu_off, measured_mu_off, abs(measured_mu_off - target_mu_off) / target_mu_off * 100);
% fprintf('  Duty cycle - 목표: %.2f, 측정: %.2f\n\n', target_rho, measured_rho);

% % 실제 트래픽 생성 테스트
% fprintf('[실제 트래픽 생성 테스트]\n');
% cfg_traffic.simulation_time = 100;  % 충분히 긴 시간
% cfg_traffic.thold_enabled = false;

% sim = Simulator(cfg_traffic);
% sim.initialize();

% % 첫 번째 STA의 패킷 간 도착 시간 분석
% sta1_pkts = sim.stas(1).packets;
% if length(sta1_pkts) > 1
%     arrival_times = [sta1_pkts.arrival_time];
    
%     % On/Off 기간 추정 (패킷 간 간격 기반)
%     inter_arrivals = diff(arrival_times);
    
%     % On 기간: 연속적인 짧은 간격들
%     % Off 기간: 긴 간격 (lambda 기반 threshold)
%     lambda = cfg_traffic.lambda;
%     mean_inter_in_on = 1 / lambda;
%     threshold = mean_inter_in_on * 5;  % On 내 간격의 5배 이상이면 Off로 간주
    
%     in_on_intervals = inter_arrivals(inter_arrivals < threshold);
%     off_intervals = inter_arrivals(inter_arrivals >= threshold);
    
%     fprintf('  총 패킷 수: %d\n', length(sta1_pkts));
%     fprintf('  총 Inter-arrival: %d개\n', length(inter_arrivals));
%     fprintf('  On 내 간격 (<%s): %d개, 평균: %.4f초\n', ...
%         sprintf('%.3f', threshold), length(in_on_intervals), mean(in_on_intervals));
    
%     if ~isempty(off_intervals)
%         fprintf('  Off 기간 (>=%.3f): %d개, 평균: %.3f초\n', ...
%             threshold, length(off_intervals), mean(off_intervals));
%     end
% end

% % 전체 STA 평균 패킷 수 검증
% total_pkts = sum([sim.stas.num_packets]);
% avg_pkts_per_sta = total_pkts / cfg_traffic.num_stas;

% % 이론적 평균 패킷 수: rho * lambda * sim_time
% expected_pkts = target_rho * cfg_traffic.lambda * cfg_traffic.simulation_time;

% fprintf('\n  평균 패킷 수/STA - 목표: %.1f, 측정: %.1f (오차: %.1f%%)\n', ...
%     expected_pkts, avg_pkts_per_sta, ...
%     abs(avg_pkts_per_sta - expected_pkts) / expected_pkts * 100);

% on_error = abs(measured_mu_on - target_mu_on) / target_mu_on * 100;
% off_error = abs(measured_mu_off - target_mu_off) / target_mu_off * 100;
% pkt_error = abs(avg_pkts_per_sta - expected_pkts) / expected_pkts * 100;

% if on_error < 15 && off_error < 15 && pkt_error < 20
%     fprintf('  ✅ PASS: 모든 트래픽 통계가 허용 범위 내 (±15-20%%)\n\n');
%     test3_pass = true;
% else
%     fprintf('  ❌ FAIL: 트래픽 통계가 허용 범위 초과\n\n');
%     test3_pass = false;
% end


% %% ═══════════════════════════════════════════════════════════════════════════
% %  최종 결과 요약
% %  ═══════════════════════════════════════════════════════════════════════════
% fprintf('═══════════════════════════════════════════════════════════════════\n');
% fprintf('검증 결과 요약\n');
% fprintf('═══════════════════════════════════════════════════════════════════\n\n');

% fprintf('┌─────────────────────────────────────────────────────────────────┐\n');
% fprintf('│ 검증 항목                          │ 결과    │ 기준               │\n');
% fprintf('├─────────────────────────────────────────────────────────────────┤\n');

% if test1_pass
%     fprintf('│ 1. 시스템 용량 (Poisson λ=200)    │ ✅ PASS │ 오차 < 5%%          │\n');
% else
%     fprintf('│ 1. 시스템 용량 (Poisson λ=200)    │ ❌ FAIL │ 오차 < 5%%          │\n');
% end

% if test2_pass
%     fprintf('│ 2. Baseline 일관성                │ ✅ PASS │ T_hold=0 = Disabled│\n');
% else
%     fprintf('│ 2. Baseline 일관성                │ ❌ FAIL │ T_hold=0 = Disabled│\n');
% end

% if test3_pass
%     fprintf('│ 3. 트래픽 모델 (Pareto On/Off)    │ ✅ PASS │ 오차 < 15-20%%      │\n');
% else
%     fprintf('│ 3. 트래픽 모델 (Pareto On/Off)    │ ❌ FAIL │ 오차 < 15-20%%      │\n');
% end

% fprintf('└─────────────────────────────────────────────────────────────────┘\n\n');

% all_pass = test1_pass && test2_pass && test3_pass;
% if all_pass
%     fprintf('🎉 모든 검증 통과! 본 실험을 시작해도 됩니다.\n\n');
% else
%     fprintf('⚠️  일부 검증 실패. 시뮬레이터 코드를 확인하세요.\n\n');
% end


% %% ═══════════════════════════════════════════════════════════════════════════
% %  추가 정보: 시스템 파라미터 상세
% %  ═══════════════════════════════════════════════════════════════════════════
% fprintf('═══════════════════════════════════════════════════════════════════\n');
% fprintf('참고: 시스템 파라미터 상세\n');
% fprintf('═══════════════════════════════════════════════════════════════════\n\n');

% fprintf('[PHY 파라미터]\n');
% fprintf('  슬롯 길이: %.0f μs\n', cfg_base.slot_duration * 1e6);
% fprintf('  SIFS: %.0f μs (%d 슬롯)\n', cfg_base.sifs * 1e6, cfg_base.sifs_slots);
% fprintf('  PHY 헤더: %.0f μs (%d 슬롯)\n', cfg_base.len_phy_header * 1e6, cfg_base.len_phy_header_slots);
% fprintf('  Trigger Frame: %.0f μs (%d 슬롯)\n', cfg_base.len_trigger_frame * 1e6, cfg_base.len_tf_slots);
% fprintf('  MU-BACK: %.0f μs (%d 슬롯)\n', cfg_base.len_mu_back * 1e6, cfg_base.len_mu_back_slots);

% fprintf('\n[데이터 전송]\n');
% fprintf('  MPDU 크기: %d bytes\n', cfg_base.mpdu_size);
% fprintf('  RU당 전송률: %.2f Mbps\n', cfg_base.data_rate_per_ru / 1e6);
% data_tx_time = cfg_base.mpdu_size * 8 / cfg_base.data_rate_per_ru;
% fprintf('  데이터 전송 시간: %.3f ms (%d 슬롯)\n', data_tx_time * 1000, cfg_base.data_tx_slots);

% fprintf('\n[Frame Exchange]\n');
% fprintf('  TF 주기: %d 슬롯 (%.3f ms)\n', cfg_base.frame_exchange_slots, ...
%     cfg_base.frame_exchange_slots * cfg_base.slot_duration * 1000);
% fprintf('  TF/초: %.2f\n', 1 / (cfg_base.frame_exchange_slots * cfg_base.slot_duration));

% fprintf('\n[용량]\n');
% fprintf('  RA-RU: %d개\n', cfg_base.num_ru_ra);
% fprintf('  SA-RU: %d개\n', cfg_base.num_ru_sa);
% fprintf('  최대 throughput: %.2f Mbps (SA-RU만 사용 시)\n', capacity_mbps);

% fprintf('\n');