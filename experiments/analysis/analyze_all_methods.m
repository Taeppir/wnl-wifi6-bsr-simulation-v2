%% analyze_all_methods_v5.m
% M0, M1(5), M2 통합 분석 - 완전판
%
% 원칙:
%   - 모든 T_hold (30, 50, 70ms) × 모든 시나리오 (A, B, C) × 모든 방법
%   - Count 위주 표시, 비율은 부가적으로
%   - 지연: mean, std, p10, p50, p90 모두 표시
%   - CDF: 모든 조합 시각화
%   - 수치는 표로, 시각화는 그래프로

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                              M0 / M1(5) / M2 통합 분석 - 완전판 v5                                                ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  데이터 로드
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('[데이터 로드]\n');

m0m1_file = 'results/main_m0_m1_fixed/results.mat';
m2_file = 'results/main_m2_fixed/results.mat';

if ~exist(m0m1_file, 'file'), error('M0/M1 결과 파일 없음: %s', m0m1_file); end
if ~exist(m2_file, 'file'), error('M2 결과 파일 없음: %s', m2_file); end

load(m0m1_file, 'results'); results_m0m1 = results;
fprintf('  ✓ M0/M1 결과 로드: %s\n', m0m1_file);
load(m2_file, 'results'); results_m2 = results;
fprintf('  ✓ M2 결과 로드: %s\n', m2_file);

%% ═══════════════════════════════════════════════════════════════════════════
%  설정
%  ═══════════════════════════════════════════════════════════════════════════
scenario_names = {'A', 'B', 'C'};
scenario_desc = {'VoIP-like (21%)', 'Video-like (69%)', 'IoT-like (42%)'};
thold_values = [30, 50, 70];
num_seeds = 3;

% MATLAB 기본 색상 팔레트
colors.Baseline = [0.5 0.5 0.5];           % 회색
colors.M0 = [0.0 0.447 0.741];             % 파랑 (MATLAB 1번)
colors.M1 = [0.850 0.325 0.098];           % 주황 (MATLAB 2번)
colors.M2 = [0.466 0.674 0.188];           % 녹색 (MATLAB 5번)

output_dir = 'results/figures_v5';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 1: Case 정의
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                         M0/M1 Case 정의                                                          ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('■ 발생 시점에 따른 분류\n');
fprintf('┌───────────────────┬──────────────────┬──────────────────┬─────────────────────────────────┐\n');
fprintf('│ Case              │ 발생 시점         │ 조건              │ 결과                             │\n');
fprintf('├───────────────────┼──────────────────┼──────────────────┼─────────────────────────────────┤\n');
fprintf('│ Hit               │ SA-RU 할당 시점   │ 버퍼에 데이터 있음 │ 전송 성공, T_hold 종료           │\n');
fprintf('│ Phantom           │ SA-RU 할당 시점   │ 버퍼 비어 있음     │ SA-RU 낭비, T_hold 유지          │\n');
fprintf('│ Clean Expiration  │ T_hold 만료 시점  │ 버퍼 비어 있음     │ RA 모드 전환                     │\n');
fprintf('│ Expiration w/Data │ T_hold 만료 시점  │ 버퍼에 패킷 있음   │ RA 모드 전환                     │\n');
fprintf('└───────────────────┴──────────────────┴──────────────────┴─────────────────────────────────┘\n\n');

fprintf('■ 통계 관계: Activations = Hits + Expirations, Expirations = Clean_Exp + Exp_with_Data\n');
fprintf('■ Phantom = 별도 카운트 (중간 이벤트, 여러 번 발생 가능)\n\n');

fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                          M2 Case 정의                                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

fprintf('■ 발생 시점에 따른 분류 (M2: 만료 후 1회만 SA-RU 시도)\n');
fprintf('┌───────────────────┬──────────────────┬──────────────────┬─────────────────────────────────┐\n');
fprintf('│ Case              │ 발생 시점         │ 조건              │ 결과                             │\n');
fprintf('├───────────────────┼──────────────────┼──────────────────┼─────────────────────────────────┤\n');
fprintf('│ Hit               │ 만료 후 SA 할당   │ 버퍼에 데이터 있음 │ 전송 성공, T_hold 종료           │\n');
fprintf('│ Phantom           │ 만료 후 SA 할당   │ 버퍼 비어 있음     │ SA-RU 낭비, RA 전환              │\n');
fprintf('│ Alloc Fail Empty  │ 만료 후 SA 미할당 │ 버퍼 비어 있음     │ RA 전환                          │\n');
fprintf('│ Alloc Fail Data   │ 만료 후 SA 미할당 │ 버퍼에 패킷 있음   │ RA 전환 (기회 못 받음)           │\n');
fprintf('└───────────────────┴──────────────────┴──────────────────┴─────────────────────────────────┘\n\n');

fprintf('■ 통계 관계: Activations = Hits + Phantoms + Alloc_Fail_Empty + Alloc_Fail_Data\n');
fprintf('■ M2 Phantom = 최종 결과 (최대 1회)\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 2: 지연 상세 통계 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                       지연 상세 통계 (모든 조합)                                                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Mean (ms)  │ Std (ms)   │ P10 (ms)   │ P50 (ms)   │ P90 (ms)   │ Count      │\n');
    fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┤\n');
    
    % Baseline
    [d_mean, d_mean_std] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.mean_ms', num_seeds);
    [d_std, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.std_ms', num_seeds);
    [d_p10, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.p10_ms', num_seeds);
    [d_p50, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.p50_ms', num_seeds);
    [d_p90, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.p90_ms', num_seeds);
    [d_cnt, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'packets.completed', num_seeds);
    fprintf('│   N/A    │ Baseline │ %7.1f±%3.1f│ %7.1f    │ %7.1f    │ %7.1f    │ %7.1f    │ %8.0f   │\n', ...
        d_mean, d_mean_std, d_std, d_p10, d_p50, d_p90, d_cnt);
    
    base_mean = d_mean;
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        % M0
        [d_mean, d_mean_std] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.mean_ms', num_seeds);
        [d_std, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.std_ms', num_seeds);
        [d_p10, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.p10_ms', num_seeds);
        [d_p50, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.p50_ms', num_seeds);
        [d_p90, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.p90_ms', num_seeds);
        [d_cnt, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'packets.completed', num_seeds);
        impr = (base_mean - d_mean) / base_mean * 100;
        fprintf('│  %3dms   │ M0       │ %7.1f±%3.1f│ %7.1f    │ %7.1f    │ %7.1f    │ %7.1f    │ %8.0f   │ %+5.1f%%\n', ...
            th, d_mean, d_mean_std, d_std, d_p10, d_p50, d_p90, d_cnt, impr);
        
        % M1(5)
        [d_mean, d_mean_std] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.mean_ms', num_seeds);
        [d_std, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.std_ms', num_seeds);
        [d_p10, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.p10_ms', num_seeds);
        [d_p50, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.p50_ms', num_seeds);
        [d_p90, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.p90_ms', num_seeds);
        [d_cnt, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'packets.completed', num_seeds);
        impr = (base_mean - d_mean) / base_mean * 100;
        fprintf('│  %3dms   │ M1(5)    │ %7.1f±%3.1f│ %7.1f    │ %7.1f    │ %7.1f    │ %7.1f    │ %8.0f   │ %+5.1f%%\n', ...
            th, d_mean, d_mean_std, d_std, d_p10, d_p50, d_p90, d_cnt, impr);
        
        % M2
        [d_mean, d_mean_std] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.mean_ms', num_seeds);
        [d_std, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.std_ms', num_seeds);
        [d_p10, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.p10_ms', num_seeds);
        [d_p50, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.p50_ms', num_seeds);
        [d_p90, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.p90_ms', num_seeds);
        [d_cnt, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'packets.completed', num_seeds);
        impr = (base_mean - d_mean) / base_mean * 100;
        fprintf('│  %3dms   │ M2       │ %7.1f±%3.1f│ %7.1f    │ %7.1f    │ %7.1f    │ %7.1f    │ %8.0f   │ %+5.1f%%\n', ...
            th, d_mean, d_mean_std, d_std, d_p10, d_p50, d_p90, d_cnt, impr);
    end
    fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┘\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 3: T_hold 상세 통계 - M0 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                       M0 T_hold 상세 통계 (Count 위주)                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Activations│    Hits    │ Expirations│ Clean_Exp  │ Exp_Data   │  Phantoms  │  Hit Rate  │\n');
    fprintf('├──────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┤\n');
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        [act, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.activations', num_seeds);
        [hits, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.hits', num_seeds);
        [exp, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.expirations', num_seeds);
        [ce, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.clean_exp', num_seeds);
        [ed, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.exp_with_data', num_seeds);
        [ph, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantoms', num_seeds);
        hr = hits / act * 100;
        
        fprintf('│  %3dms   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', ...
            th, act, hits, exp, ce, ed, ph, hr);
    end
    fprintf('└──────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┘\n');
    fprintf('  검증: Activations = Hits + Expirations, Expirations = Clean_Exp + Exp_Data\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 4: T_hold 상세 통계 - M1(5) (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                      M1(5) T_hold 상세 통계 (Count 위주)                                          ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Activations│    Hits    │ Expirations│ Clean_Exp  │ Exp_Data   │  Phantoms  │  Hit Rate  │\n');
    fprintf('├──────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┤\n');
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        [act, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.activations', num_seeds);
        [hits, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.hits', num_seeds);
        [exp, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.expirations', num_seeds);
        [ce, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.clean_exp', num_seeds);
        [ed, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.exp_with_data', num_seeds);
        [ph, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.phantoms', num_seeds);
        hr = hits / act * 100;
        
        fprintf('│  %3dms   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', ...
            th, act, hits, exp, ce, ed, ph, hr);
    end
    fprintf('└──────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┘\n');
    fprintf('  M1(5): Phantom 5회 도달 시 즉시 RA 전환\n');
    fprintf('  Note: Activations = Hits + Expirations + Phantom5_Exit (표에 미표시)\n');
    fprintf('        Phantom5_Exit = Phantom 5회로 강제 종료된 T_hold 수\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 5: T_hold 상세 통계 - M2 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                       M2 T_hold 상세 통계 (Count 위주)                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬────────────┬────────────┬────────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Activations│    Hits    │  Phantoms  │ AllocEmpty │ AllocData  │  Hit Rate  │\n');
    fprintf('├──────────┼────────────┼────────────┼────────────┼────────────┼────────────┼────────────┤\n');
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        [act, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.activations', num_seeds);
        [hits, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.hits', num_seeds);
        [ph, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.phantoms', num_seeds);
        [ce, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.clean_exp', num_seeds);
        [ed, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.exp_with_data', num_seeds);
        hr = hits / act * 100;
        
        fprintf('│  %3dms   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', ...
            th, act, hits, ph, ce, ed, hr);
    end
    fprintf('└──────────┴────────────┴────────────┴────────────┴────────────┴────────────┴────────────┘\n');
    fprintf('  검증: Activations ≈ Hits + Phantoms + AllocEmpty + AllocData (경계오차 허용)\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 6: UORA 상세 통계 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                       UORA 상세 통계 (모든 조합)                                                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Attempts   │ Successes  │ Collisions │ Coll Rate  │\n');
    fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┤\n');
    
    % Baseline
    [att, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.total_attempts', num_seeds);
    [suc, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.total_success', num_seeds);
    [col, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.total_collision', num_seeds);
    cr = col / att * 100;
    fprintf('│   N/A    │ Baseline │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', att, suc, col, cr);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        % M0
        [att, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.total_attempts', num_seeds);
        [suc, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.total_success', num_seeds);
        [col, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.total_collision', num_seeds);
        cr = col / att * 100;
        fprintf('│  %3dms   │ M0       │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', th, att, suc, col, cr);
        
        % M1(5)
        [att, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.total_attempts', num_seeds);
        [suc, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.total_success', num_seeds);
        [col, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.total_collision', num_seeds);
        cr = col / att * 100;
        fprintf('│  %3dms   │ M1(5)    │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', th, att, suc, col, cr);
        
        % M2
        [att, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.total_attempts', num_seeds);
        [suc, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.total_success', num_seeds);
        [col, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.total_collision', num_seeds);
        cr = col / att * 100;
        fprintf('│  %3dms   │ M2       │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', th, att, suc, col, cr);
    end
    fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┴────────────┘\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 7: BSR 상세 통계 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                        BSR 상세 통계 (모든 조합)                                                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Implicit   │ Explicit   │ Total      │\n');
    fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┤\n');
    
    % Baseline
    [impl, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'bsr.implicit_count', num_seeds);
    [expl, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'bsr.explicit_count', num_seeds);
    fprintf('│   N/A    │ Baseline │ %8.0f   │ %8.0f   │ %8.0f   │\n', impl, expl, impl+expl);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        % M0
        [impl, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'bsr.implicit_count', num_seeds);
        [expl, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'bsr.explicit_count', num_seeds);
        fprintf('│  %3dms   │ M0       │ %8.0f   │ %8.0f   │ %8.0f   │\n', th, impl, expl, impl+expl);
        
        % M1(5)
        [impl, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'bsr.implicit_count', num_seeds);
        [expl, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'bsr.explicit_count', num_seeds);
        fprintf('│  %3dms   │ M1(5)    │ %8.0f   │ %8.0f   │ %8.0f   │\n', th, impl, expl, impl+expl);
        
        % M2
        [impl, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'bsr.implicit_count', num_seeds);
        [expl, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'bsr.explicit_count', num_seeds);
        fprintf('│  %3dms   │ M2       │ %8.0f   │ %8.0f   │ %8.0f   │\n', th, impl, expl, impl+expl);
    end
    fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┘\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 8: Throughput & Packet 통계 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                    Throughput & Packet 통계 (모든 조합)                                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Throughput │ Generated  │ Completed  │ Dropped    │ Completion │\n');
    fprintf('│          │          │ (Mbps)     │            │            │            │ Rate       │\n');
    fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┼────────────┼────────────┤\n');
    
    % Baseline
    [tp, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.total_mbps', num_seeds);
    [gen, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'packets.generated', num_seeds);
    [comp, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'packets.completed', num_seeds);
    [drop, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'packets.dropped', num_seeds);
    cr = comp / gen * 100;
    fprintf('│   N/A    │ Baseline │ %8.2f   │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', tp, gen, comp, drop, cr);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        % M0
        [tp, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.total_mbps', num_seeds);
        [gen, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'packets.generated', num_seeds);
        [comp, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'packets.completed', num_seeds);
        [drop, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'packets.dropped', num_seeds);
        cr = comp / gen * 100;
        fprintf('│  %3dms   │ M0       │ %8.2f   │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', th, tp, gen, comp, drop, cr);
        
        % M1(5)
        [tp, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.total_mbps', num_seeds);
        [gen, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'packets.generated', num_seeds);
        [comp, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'packets.completed', num_seeds);
        [drop, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'packets.dropped', num_seeds);
        cr = comp / gen * 100;
        fprintf('│  %3dms   │ M1(5)    │ %8.2f   │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', th, tp, gen, comp, drop, cr);
        
        % M2
        [tp, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.total_mbps', num_seeds);
        [gen, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'packets.generated', num_seeds);
        [comp, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'packets.completed', num_seeds);
        [drop, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'packets.dropped', num_seeds);
        cr = comp / gen * 100;
        fprintf('│  %3dms   │ M2       │ %8.2f   │ %8.0f   │ %8.0f   │ %8.0f   │ %6.1f%%    │\n', th, tp, gen, comp, drop, cr);
    end
    fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┴────────────┴────────────┘\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 9: Fairness 통계 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                        Fairness 통계 (모든 조합)                                                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬──────────┬────────────┐\n');
    fprintf('│ T_hold   │ Method   │ Jain Index │\n');
    fprintf('├──────────┼──────────┼────────────┤\n');
    
    % Baseline
    [jain, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'fairness.jain_index', num_seeds);
    fprintf('│   N/A    │ Baseline │   %.4f   │\n', jain);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        [jain, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'fairness.jain_index', num_seeds);
        fprintf('│  %3dms   │ M0       │   %.4f   │\n', th, jain);
        
        [jain, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'fairness.jain_index', num_seeds);
        fprintf('│  %3dms   │ M1(5)    │   %.4f   │\n', th, jain);
        
        [jain, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'fairness.jain_index', num_seeds);
        fprintf('│  %3dms   │ M2       │   %.4f   │\n', th, jain);
    end
    fprintf('└──────────┴──────────┴────────────┘\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 10: RU Utilization 통계 (모든 조합)
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                     RU Utilization 통계 (모든 조합)                                               ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    fprintf('[시나리오 %s: %s]\n', sc, scenario_desc{sc_idx});
    fprintf('┌──────────┬──────────┬────────────┬────────────┬────────────┐\n');
    fprintf('│ T_hold   │ Method   │ SA Util    │ RA Util    │ Channel    │\n');
    fprintf('├──────────┼──────────┼────────────┼────────────┼────────────┤\n');
    
    % Baseline
    [sa_u, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.sa_utilization', num_seeds);
    [ra_u, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.ra_utilization', num_seeds);
    [ch_u, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.channel_utilization', num_seeds);
    fprintf('│   N/A    │ Baseline │ %7.1f%%   │ %7.1f%%   │ %7.1f%%   │\n', sa_u*100, ra_u*100, ch_u*100);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        
        % M0
        [sa_u, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.sa_utilization', num_seeds);
        [ra_u, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.ra_utilization', num_seeds);
        [ch_u, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.channel_utilization', num_seeds);
        fprintf('│  %3dms   │ M0       │ %7.1f%%   │ %7.1f%%   │ %7.1f%%   │\n', th, sa_u*100, ra_u*100, ch_u*100);
        
        % M1(5)
        [sa_u, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.sa_utilization', num_seeds);
        [ra_u, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.ra_utilization', num_seeds);
        [ch_u, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.channel_utilization', num_seeds);
        fprintf('│  %3dms   │ M1(5)    │ %7.1f%%   │ %7.1f%%   │ %7.1f%%   │\n', th, sa_u*100, ra_u*100, ch_u*100);
        
        % M2
        [sa_u, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.sa_utilization', num_seeds);
        [ra_u, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.ra_utilization', num_seeds);
        [ch_u, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.channel_utilization', num_seeds);
        fprintf('│  %3dms   │ M2       │ %7.1f%%   │ %7.1f%%   │ %7.1f%%   │\n', th, sa_u*100, ra_u*100, ch_u*100);
    end
    fprintf('└──────────┴──────────┴────────────┴────────────┴────────────┘\n\n');
end

%% ═══════════════════════════════════════════════════════════════════════════
%  PART 11: Figure 생성
%  ═══════════════════════════════════════════════════════════════════════════
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                           Figure 생성                                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');

%% Figure 1: Delay CDF - 모든 조합 (3x3x4 = 36 curves in 9 subplots)
figure('Name', 'Fig 1: Delay CDF (All)', 'Position', [50 50 1600 1000]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    for th_idx = 1:3
        th = thold_values(th_idx);
        subplot(3, 3, (sc_idx-1)*3 + th_idx);
        
        % Baseline
        field = sprintf('%s_Baseline_s1', sc);
        if isfield(results_m0m1.runs, field)
            [x, f] = manual_cdf(results_m0m1.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.Baseline, 'LineWidth', 2); hold on;
        end
        
        % M0
        field = sprintf('%s_T%d_M0_s1', sc, th);
        if isfield(results_m0m1.runs, field)
            [x, f] = manual_cdf(results_m0m1.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.M0, 'LineWidth', 2);
        end
        
        % M1(5)
        field = sprintf('%s_T%d_M1_5_s1', sc, th);
        if isfield(results_m0m1.runs, field)
            [x, f] = manual_cdf(results_m0m1.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.M1, 'LineWidth', 2);
        end
        
        % M2
        field = sprintf('%s_T%d_M2_s1', sc, th);
        if isfield(results_m2.runs, field)
            [x, f] = manual_cdf(results_m2.runs.(field).delay.all_ms);
            plot(x, f, '-', 'Color', colors.M2, 'LineWidth', 2);
        end
        
        yline(0.5, ':', 'P50', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
        yline(0.9, ':', 'P90', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
        hold off;
        
        xlabel('Delay (ms)'); ylabel('CDF');
        title(sprintf('%s - T_{hold}=%dms', sc, th));
        if sc_idx == 1 && th_idx == 1
            legend({'Baseline', 'M0', 'M1(5)', 'M2'}, 'Location', 'southeast', 'FontSize', 8);
        end
        xlim([0 300]); ylim([0 1]); grid on;
    end
end
sgtitle('Figure 1: Delay CDF (모든 조합)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig01_delay_cdf_all.png'));
fprintf('  ✓ Figure 1: Delay CDF 저장\n');

%% Figure 2: Mean Delay 추이
figure('Name', 'Fig 2: Mean Delay Trend', 'Position', [100 100 1400 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_d = zeros(1,3); m1_d = zeros(1,3); m2_d = zeros(1,3);
    m0_std = zeros(1,3); m1_std = zeros(1,3); m2_std = zeros(1,3);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_d(th_idx), m0_std(th_idx)] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.mean_ms', num_seeds);
        [m1_d(th_idx), m1_std(th_idx)] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.mean_ms', num_seeds);
        [m2_d(th_idx), m2_std(th_idx)] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.mean_ms', num_seeds);
    end
    [base_d, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.mean_ms', num_seeds);
    
    errorbar(thold_values, m0_d, m0_std, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    errorbar(thold_values, m1_d, m1_std, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerFaceColor', colors.M1);
    errorbar(thold_values, m2_d, m2_std, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_d, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 2);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Mean Delay (ms)');
    title(sprintf('%s: %s', sc, scenario_desc{sc_idx}));
    if sc_idx == 3, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); grid on;
end
sgtitle('Figure 2: Mean Delay 추이 (Error bar = std)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig02_delay_trend.png'));
fprintf('  ✓ Figure 2: Mean Delay 추이 저장\n');

%% Figure 3: Phantom Count 추이
figure('Name', 'Fig 3: Phantom Trend', 'Position', [100 100 1400 400]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    subplot(1, 3, sc_idx);
    
    m0_ph = zeros(1,3); m1_ph = zeros(1,3); m2_ph = zeros(1,3);
    
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_ph(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantoms', num_seeds);
        [m1_ph(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.phantoms', num_seeds);
        [m2_ph(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.phantoms', num_seeds);
    end
    
    plot(thold_values, m0_ph, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_ph, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerFaceColor', colors.M1);
    plot(thold_values, m2_ph, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('Phantom Count');
    title(sprintf('%s: %s', sc, scenario_desc{sc_idx}));
    if sc_idx == 3, legend({'M0', 'M1(5)', 'M2'}, 'Location', 'best'); end
    xlim([25 75]); grid on;
end
sgtitle('Figure 3: Phantom Count 추이', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig03_phantom_trend.png'));
fprintf('  ✓ Figure 3: Phantom 추이 저장\n');

%% Figure 4: Hit Count, Activation Count, Hit Rate 추이
figure('Name', 'Fig 4: Hit & Activation & Rate', 'Position', [100 100 1400 1000]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    
    % Hits
    subplot(3, 3, sc_idx);
    m0_h = zeros(1,3); m1_h = zeros(1,3); m2_h = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_h(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.hits', num_seeds);
        [m1_h(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.hits', num_seeds);
        [m2_h(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.hits', num_seeds);
    end
    plot(thold_values, m0_h, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_h, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerFaceColor', colors.M1);
    plot(thold_values, m2_h, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    hold off;
    xlabel('T_{hold} (ms)'); ylabel('Hit Count');
    title(sprintf('%s: Hits', sc));
    if sc_idx == 3, legend({'M0', 'M1(5)', 'M2'}, 'Location', 'best'); end
    xlim([25 75]); grid on;
    
    % Activations
    subplot(3, 3, sc_idx + 3);
    m0_a = zeros(1,3); m1_a = zeros(1,3); m2_a = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_a(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.activations', num_seeds);
        [m1_a(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.activations', num_seeds);
        [m2_a(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.activations', num_seeds);
    end
    plot(thold_values, m0_a, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_a, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerFaceColor', colors.M1);
    plot(thold_values, m2_a, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    hold off;
    xlabel('T_{hold} (ms)'); ylabel('Activation Count');
    title(sprintf('%s: Activations', sc));
    xlim([25 75]); grid on;
    
    % Hit Rate
    subplot(3, 3, sc_idx + 6);
    m0_r = zeros(1,3); m1_r = zeros(1,3); m2_r = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_r(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.hit_rate', num_seeds);
        [m1_r(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.hit_rate', num_seeds);
        [m2_r(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.hit_rate', num_seeds);
    end
    plot(thold_values, m0_r*100, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_r*100, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerFaceColor', colors.M1);
    plot(thold_values, m2_r*100, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    hold off;
    xlabel('T_{hold} (ms)'); ylabel('Hit Rate (%)');
    title(sprintf('%s: Hit Rate', sc));
    xlim([25 75]); ylim([0 100]); grid on;
end
sgtitle('Figure 4: Hit Count, Activation Count, Hit Rate 추이', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig04_hit_activation_rate.png'));
fprintf('  ✓ Figure 4: Hit & Activation & Rate 저장\n');

%% Figure 5: UORA 상세 (3x3 subplot - 모든 T_hold)
figure('Name', 'Fig 5: UORA Detail', 'Position', [100 100 1400 1000]);

% MATLAB 기본 색상: Success (녹색), Collision (빨강), Idle (회색)
uora_colors = [0.466 0.674 0.188;   % Success - 연녹색
               0.635 0.078 0.184;   % Collision - 빨강
               0.7 0.7 0.7];        % Idle - 회색

for th_idx = 1:3
    th = thold_values(th_idx);
    
    for sc_idx = 1:3
        sc = scenario_names{sc_idx};
        subplot(3, 3, (th_idx-1)*3 + sc_idx);
        
        % 데이터 수집
        [base_suc, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.total_success', num_seeds);
        [base_col, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.total_collision', num_seeds);
        [base_idle, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'uora.total_idle', num_seeds);
        
        [m0_suc, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.total_success', num_seeds);
        [m0_col, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.total_collision', num_seeds);
        [m0_idle, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'uora.total_idle', num_seeds);
        
        [m1_suc, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.total_success', num_seeds);
        [m1_col, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.total_collision', num_seeds);
        [m1_idle, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'uora.total_idle', num_seeds);
        
        [m2_suc, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.total_success', num_seeds);
        [m2_col, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.total_collision', num_seeds);
        [m2_idle, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'uora.total_idle', num_seeds);
        
        suc_data = [base_suc, m0_suc, m1_suc, m2_suc];
        col_data = [base_col, m0_col, m1_col, m2_col];
        idle_data = [base_idle, m0_idle, m1_idle, m2_idle];
        
        data = [suc_data; col_data; idle_data]';
        b = bar(data, 'stacked');
        b(1).FaceColor = uora_colors(1,:);  % Success
        b(2).FaceColor = uora_colors(2,:);  % Collision
        b(3).FaceColor = uora_colors(3,:);  % Idle
        
        set(gca, 'XTickLabel', {'Base', 'M0', 'M1', 'M2'});
        ylabel('Count');
        title(sprintf('%s T_{hold}=%dms', sc, th));
        if th_idx == 1 && sc_idx == 3
            legend({'Success', 'Collision', 'Idle'}, 'Location', 'northeast', 'FontSize', 7);
        end
        grid on;
        
        % Collision Rate 표시
        for i = 1:4
            att = suc_data(i) + col_data(i);
            if att > 0
                coll_rate = col_data(i) / att * 100;
                total = suc_data(i) + col_data(i) + idle_data(i);
                text(i, total + max(suc_data+col_data+idle_data)*0.02, sprintf('%.0f%%', coll_rate), ...
                    'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [0.6 0.1 0.1]);
            end
        end
    end
end
sgtitle('Figure 5: UORA 상세 (Success + Collision + Idle)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig05_uora_detail.png'));
fprintf('  ✓ Figure 5: UORA Detail 저장\n');

%% Figure 6: Trade-off 분석 (2 subplot: Delay vs Phantom, Hit Rate vs Delay)
figure('Name', 'Fig 6: Trade-off', 'Position', [100 100 1400 900]);

th = 50;  % 대표값
marker_size = 150;

method_names = {'Baseline', 'M0', 'M1(5)', 'M2'};
method_colors = {colors.Baseline, colors.M0, colors.M1, colors.M2};

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    
    % 데이터 수집
    [base_d, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay.mean_ms', num_seeds);
    [m0_d, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay.mean_ms', num_seeds);
    [m1_d, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay.mean_ms', num_seeds);
    [m2_d, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay.mean_ms', num_seeds);
    
    [m0_ph, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.phantoms', num_seeds);
    [m1_ph, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.phantoms', num_seeds);
    [m2_ph, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.phantoms', num_seeds);
    
    [m0_hr, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.hit_rate', num_seeds);
    [m1_hr, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.hit_rate', num_seeds);
    [m2_hr, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.hit_rate', num_seeds);
    
    delays = [base_d, m0_d, m1_d, m2_d];
    phantoms = [0, m0_ph, m1_ph, m2_ph];  % Baseline은 phantom 없음
    hit_rates = [0, m0_hr*100, m1_hr*100, m2_hr*100];  % Baseline은 hit rate 없음
    
    %% Subplot 1: Delay vs Phantom
    subplot(2, 3, sc_idx);
    
    % Baseline line
    yline(base_d, '--', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold on;
    
    % M0, M1, M2 scatter
    for i = 2:4  % Skip Baseline (no phantom)
        scatter(phantoms(i), delays(i), marker_size, method_colors{i}, 'filled', 'MarkerEdgeColor', 'k');
        text(phantoms(i), delays(i) + 5, method_names{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
    end
    hold off;
    
    xlabel('Phantom Count'); ylabel('Mean Delay (ms)');
    title(sprintf('%s: 지연 vs Phantom', sc));
    grid on;
    xlim([0 max(phantoms)*1.1]);
    ylim([0 max(delays)*1.2]);
    
    %% Subplot 2: Hit Rate vs Delay
    subplot(2, 3, sc_idx + 3);
    
    % Baseline line
    yline(base_d, '--', 'Color', colors.Baseline, 'LineWidth', 1.5);
    hold on;
    
    % M0, M1, M2 scatter
    for i = 2:4  % Skip Baseline
        scatter(hit_rates(i), delays(i), marker_size, method_colors{i}, 'filled', 'MarkerEdgeColor', 'k');
        text(hit_rates(i), delays(i) + 5, method_names{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
    end
    hold off;
    
    xlabel('Hit Rate (%)'); ylabel('Mean Delay (ms)');
    title(sprintf('%s: Hit Rate vs 지연', sc));
    grid on;
    xlim([0 100]);
    ylim([0 max(delays)*1.2]);
end
sgtitle(sprintf('Figure 6: Trade-off 분석 (T_{hold}=%dms)', th), 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig06_tradeoff.png'));
fprintf('  ✓ Figure 6: Trade-off 저장\n');

%% Figure 7: Throughput 비교 (3x3 - 모든 T_hold)
figure('Name', 'Fig 7: Throughput', 'Position', [100 100 1400 1000]);

methods_labels = {'Base', 'M0', 'M1', 'M2'};

for th_idx = 1:3
    th = thold_values(th_idx);
    
    for sc_idx = 1:3
        sc = scenario_names{sc_idx};
        subplot(3, 3, (th_idx-1)*3 + sc_idx);
        
        [base_t, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.total_mbps', num_seeds);
        [m0_t, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.total_mbps', num_seeds);
        [m1_t, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.total_mbps', num_seeds);
        [m2_t, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.total_mbps', num_seeds);
        
        data = [base_t, m0_t, m1_t, m2_t];
        b = bar(data, 'FaceColor', 'flat');
        b.CData = [colors.Baseline; colors.M0; colors.M1; colors.M2];
        
        set(gca, 'XTickLabel', methods_labels);
        ylabel('Mbps');
        title(sprintf('%s T_{hold}=%dms', sc, th));
        ylim([0 max(data)*1.15]);
        grid on;
        
        % 값 표시
        for i = 1:4
            text(i, data(i)+max(data)*0.02, sprintf('%.1f', data(i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 7);
        end
    end
end
sgtitle('Figure 7: Throughput 비교', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig07_throughput.png'));
fprintf('  ✓ Figure 7: Throughput 저장\n');

%% Figure 8: Fairness 비교 (3x3 - 모든 T_hold)
figure('Name', 'Fig 8: Fairness', 'Position', [100 100 1400 1000]);

methods_labels = {'Base', 'M0', 'M1', 'M2'};

for th_idx = 1:3
    th = thold_values(th_idx);
    
    for sc_idx = 1:3
        sc = scenario_names{sc_idx};
        subplot(3, 3, (th_idx-1)*3 + sc_idx);
        
        [base_f, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'fairness.jain_index', num_seeds);
        [m0_f, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'fairness.jain_index', num_seeds);
        [m1_f, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'fairness.jain_index', num_seeds);
        [m2_f, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'fairness.jain_index', num_seeds);
        
        data = [base_f, m0_f, m1_f, m2_f];
        b = bar(data, 'FaceColor', 'flat');
        b.CData = [colors.Baseline; colors.M0; colors.M1; colors.M2];
        
        set(gca, 'XTickLabel', methods_labels);
        ylabel('Jain Index');
        title(sprintf('%s T_{hold}=%dms', sc, th));
        ylim([0.9 1.0]);
        grid on;
        
        % 값 표시
        for i = 1:4
            text(i, data(i)+0.002, sprintf('%.4f', data(i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 6);
        end
    end
end
sgtitle('Figure 8: Jain''s Fairness Index 비교', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig08_fairness.png'));
fprintf('  ✓ Figure 8: Fairness 저장\n');

%% Figure 9: Expiration 상세 (M0, M1(5), M2)
figure('Name', 'Fig 9: Expiration Detail', 'Position', [100 100 1400 1000]);

% MATLAB 기본 색상
exp_colors = [0.301 0.745 0.933;   % Clean/AllocEmpty - 하늘색
              0.850 0.325 0.098];  % Exp_Data/AllocData - 주황

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    
    %% M0 Expirations
    subplot(3, 3, sc_idx);
    m0_ce = zeros(1,3); m0_ed = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_ce(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.clean_exp', num_seeds);
        [m0_ed(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'thold.exp_with_data', num_seeds);
    end
    data_m0 = [m0_ce; m0_ed]';
    b = bar(data_m0, 'stacked');
    b(1).FaceColor = exp_colors(1,:);
    b(2).FaceColor = exp_colors(2,:);
    set(gca, 'XTickLabel', {'30ms', '50ms', '70ms'});
    xlabel('T_{hold}'); ylabel('Count');
    title(sprintf('%s: M0 Expirations', sc));
    if sc_idx == 3
        legend({'Clean Exp', 'Exp w/ Data'}, 'Location', 'northeast');
    end
    grid on;
    
    % 수치 표시
    for th_idx = 1:3
        total = m0_ce(th_idx) + m0_ed(th_idx);
        text(th_idx, total + max(m0_ce+m0_ed)*0.03, sprintf('%d', round(total)), ...
            'HorizontalAlignment', 'center', 'FontSize', 8);
    end
    
    %% M1(5) Expirations
    subplot(3, 3, sc_idx + 3);
    m1_ce = zeros(1,3); m1_ed = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m1_ce(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.clean_exp', num_seeds);
        [m1_ed(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'thold.exp_with_data', num_seeds);
    end
    data_m1 = [m1_ce; m1_ed]';
    b = bar(data_m1, 'stacked');
    b(1).FaceColor = exp_colors(1,:);
    b(2).FaceColor = exp_colors(2,:);
    set(gca, 'XTickLabel', {'30ms', '50ms', '70ms'});
    xlabel('T_{hold}'); ylabel('Count');
    title(sprintf('%s: M1(5) Expirations', sc));
    grid on;
    
    % 수치 표시
    for th_idx = 1:3
        total = m1_ce(th_idx) + m1_ed(th_idx);
        if total > 0
            text(th_idx, total + max(max(m1_ce+m1_ed), 1)*0.05, sprintf('%d', round(total)), ...
                'HorizontalAlignment', 'center', 'FontSize', 8);
        else
            text(th_idx, 0.5, '0', 'HorizontalAlignment', 'center', 'FontSize', 8);
        end
    end
    
    %% M2 Allocation Failures
    subplot(3, 3, sc_idx + 6);
    m2_ae = zeros(1,3); m2_ad = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m2_ae(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.clean_exp', num_seeds);
        [m2_ad(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'thold.exp_with_data', num_seeds);
    end
    data_m2 = [m2_ae; m2_ad]';
    b = bar(data_m2, 'stacked');
    b(1).FaceColor = exp_colors(1,:);
    b(2).FaceColor = exp_colors(2,:);
    set(gca, 'XTickLabel', {'30ms', '50ms', '70ms'});
    xlabel('T_{hold}'); ylabel('Count');
    title(sprintf('%s: M2 Alloc Failures', sc));
    if sc_idx == 3
        legend({'Alloc Fail (Empty)', 'Alloc Fail (Data)'}, 'Location', 'northeast');
    end
    grid on;
    
    % 수치 표시
    for th_idx = 1:3
        total = m2_ae(th_idx) + m2_ad(th_idx);
        if total > 0
            text(th_idx, total + max(max(m2_ae+m2_ad), 1)*0.05, sprintf('%d', round(total)), ...
                'HorizontalAlignment', 'center', 'FontSize', 8);
        end
    end
end
sgtitle('Figure 9: Expiration / Allocation Failure 상세', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig09_expiration_detail.png'));
fprintf('  ✓ Figure 9: Expiration Detail 저장\n');

%% Figure 10: BSR Count (3x3 Stacked Bar - 모든 T_hold)
figure('Name', 'Fig 10: BSR Stacked', 'Position', [100 100 1400 1000]);

% MATLAB 기본 색상
bsr_colors = [0.0 0.447 0.741;    % Implicit - 파랑
              0.850 0.325 0.098]; % Explicit - 주황

for th_idx = 1:3
    th = thold_values(th_idx);
    
    for sc_idx = 1:3
        sc = scenario_names{sc_idx};
        subplot(3, 3, (th_idx-1)*3 + sc_idx);
        
        % 데이터 수집
        [base_impl, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'bsr.implicit_count', num_seeds);
        [base_expl, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'bsr.explicit_count', num_seeds);
        [m0_impl, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'bsr.implicit_count', num_seeds);
        [m0_expl, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'bsr.explicit_count', num_seeds);
        [m1_impl, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'bsr.implicit_count', num_seeds);
        [m1_expl, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'bsr.explicit_count', num_seeds);
        [m2_impl, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'bsr.implicit_count', num_seeds);
        [m2_expl, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'bsr.explicit_count', num_seeds);
        
        impl_data = [base_impl, m0_impl, m1_impl, m2_impl];
        expl_data = [base_expl, m0_expl, m1_expl, m2_expl];
        
        data = [impl_data; expl_data]';
        b = bar(data, 'stacked');
        b(1).FaceColor = bsr_colors(1,:);  % Implicit (아래)
        b(2).FaceColor = bsr_colors(2,:);  % Explicit (위)
        
        set(gca, 'XTickLabel', {'Base', 'M0', 'M1', 'M2'});
        ylabel('BSR Count');
        title(sprintf('%s T_{hold}=%dms', sc, th));
        if th_idx == 1 && sc_idx == 3
            legend({'Implicit', 'Explicit'}, 'Location', 'northeast', 'FontSize', 7);
        end
        grid on;
        ylim([0 max(impl_data + expl_data) * 1.1]);
    end
end
sgtitle('Figure 10: BSR Count (Implicit + Explicit)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig10_bsr_stacked.png'));
fprintf('  ✓ Figure 10: BSR Stacked 저장\n');

%% Figure 11: 패킷 분류별 개수 (3x3 Stacked Bar - 모든 T_hold)
figure('Name', 'Fig 11: Packet Classification', 'Position', [100 100 1400 1000]);

% MATLAB 기본 색상
pkt_colors = [0.0 0.447 0.741;    % UORA Used - 파랑
              0.850 0.325 0.098;  % SA Queue - 주황
              0.929 0.694 0.125]; % T_hold Hit - 노랑

for th_idx = 1:3
    th = thold_values(th_idx);
    
    for sc_idx = 1:3
        sc = scenario_names{sc_idx};
        subplot(3, 3, (th_idx-1)*3 + sc_idx);
        
        % Baseline
        [base_uora, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'pkt_class.uora_used.count', num_seeds);
        [base_sa, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'pkt_class.sa_queue.count', num_seeds);
        [base_hit, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'pkt_class.thold_hit.count', num_seeds);
        
        % M0
        [m0_uora, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'pkt_class.uora_used.count', num_seeds);
        [m0_sa, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'pkt_class.sa_queue.count', num_seeds);
        [m0_hit, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'pkt_class.thold_hit.count', num_seeds);
        
        % M1(5)
        [m1_uora, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'pkt_class.uora_used.count', num_seeds);
        [m1_sa, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'pkt_class.sa_queue.count', num_seeds);
        [m1_hit, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'pkt_class.thold_hit.count', num_seeds);
        
        % M2
        [m2_uora, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'pkt_class.uora_used.count', num_seeds);
        [m2_sa, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'pkt_class.sa_queue.count', num_seeds);
        [m2_hit, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'pkt_class.thold_hit.count', num_seeds);
        
        uora_data = [base_uora, m0_uora, m1_uora, m2_uora];
        sa_data = [base_sa, m0_sa, m1_sa, m2_sa];
        hit_data = [base_hit, m0_hit, m1_hit, m2_hit];
        
        % NaN 처리
        uora_data(isnan(uora_data)) = 0;
        sa_data(isnan(sa_data)) = 0;
        hit_data(isnan(hit_data)) = 0;
        
        data = [uora_data; sa_data; hit_data]';
        b = bar(data, 'stacked');
        b(1).FaceColor = pkt_colors(1,:);  % UORA Used
        b(2).FaceColor = pkt_colors(2,:);  % SA Queue
        b(3).FaceColor = pkt_colors(3,:);  % T_hold Hit
        
        set(gca, 'XTickLabel', {'Base', 'M0', 'M1', 'M2'});
        ylabel('Count');
        title(sprintf('%s T_{hold}=%dms', sc, th));
        if th_idx == 1 && sc_idx == 3
            legend({'UORA', 'SA Queue', 'T_{hold} Hit'}, 'Location', 'northeast', 'FontSize', 7);
        end
        grid on;
        
        total_data = uora_data + sa_data + hit_data;
        ylim([0 max(total_data) * 1.1]);
    end
end
sgtitle('Figure 11: 패킷 분류별 개수', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig11_packet_classification.png'));
fprintf('  ✓ Figure 11: Packet Classification 저장\n');

%% Figure 12: 지연 분해 (3x3 Stacked Bar - 모든 T_hold)
figure('Name', 'Fig 12: Delay Decomposition', 'Position', [100 100 1400 1000]);

% MATLAB 기본 색상: Initial Wait (파랑), UORA (주황), SA Wait (노랑)
delay_colors = [0.0 0.447 0.741;    % Initial Wait - 파랑
                0.850 0.325 0.098;  % UORA Contention - 주황
                0.929 0.694 0.125]; % SA Wait - 노랑

for th_idx = 1:3
    th = thold_values(th_idx);
    
    for sc_idx = 1:3
        sc = scenario_names{sc_idx};
        subplot(3, 3, (th_idx-1)*3 + sc_idx);
        
        % Baseline
        [base_init, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay_decomp.initial_wait.mean_ms', num_seeds);
        [base_uora, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay_decomp.uora_contention.mean_ms', num_seeds);
        [base_sa, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'delay_decomp.sa_wait.mean_ms', num_seeds);
        
        % M0
        [m0_init, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay_decomp.initial_wait.mean_ms', num_seeds);
        [m0_uora, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay_decomp.uora_contention.mean_ms', num_seeds);
        [m0_sa, ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'delay_decomp.sa_wait.mean_ms', num_seeds);
        
        % M1(5)
        [m1_init, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay_decomp.initial_wait.mean_ms', num_seeds);
        [m1_uora, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay_decomp.uora_contention.mean_ms', num_seeds);
        [m1_sa, ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'delay_decomp.sa_wait.mean_ms', num_seeds);
        
        % M2
        [m2_init, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay_decomp.initial_wait.mean_ms', num_seeds);
        [m2_uora, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay_decomp.uora_contention.mean_ms', num_seeds);
        [m2_sa, ~] = get_metric_avg(results_m2, sc, th, 'M2', 'delay_decomp.sa_wait.mean_ms', num_seeds);
        
        % 순서: Initial Wait (아래), UORA (중간), SA Wait (위)
        init_data = [base_init, m0_init, m1_init, m2_init];
        uora_data = [base_uora, m0_uora, m1_uora, m2_uora];
        sa_data = [base_sa, m0_sa, m1_sa, m2_sa];
        
        % NaN 처리
        init_data(isnan(init_data)) = 0;
        uora_data(isnan(uora_data)) = 0;
        sa_data(isnan(sa_data)) = 0;
        
        data = [init_data; uora_data; sa_data]';
        b = bar(data, 'stacked');
        b(1).FaceColor = delay_colors(1,:);  % Initial Wait
        b(2).FaceColor = delay_colors(2,:);  % UORA Contention
        b(3).FaceColor = delay_colors(3,:);  % SA Wait
        
        set(gca, 'XTickLabel', {'Base', 'M0', 'M1', 'M2'});
        ylabel('Delay (ms)');
        title(sprintf('%s T_{hold}=%dms', sc, th));
        if th_idx == 1 && sc_idx == 3
            legend({'Init', 'UORA', 'SA'}, 'Location', 'northeast', 'FontSize', 7);
        end
        grid on;
        
        total_data = init_data + uora_data + sa_data;
        ylim([0 max(total_data) * 1.15]);
        
        % 총 지연 수치 표시
        for i = 1:4
            text(i, total_data(i) + max(total_data)*0.02, sprintf('%.0f', total_data(i)), ...
                'HorizontalAlignment', 'center', 'FontSize', 7);
        end
    end
end
sgtitle('Figure 12: 지연 분해', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig12_delay_decomposition.png'));
fprintf('  ✓ Figure 12: Delay Decomposition 저장\n');
sgtitle(sprintf('Figure 12: 지연 분해 (T_{hold}=%dms)', th), 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig12_delay_decomposition.png'));
fprintf('  ✓ Figure 12: Delay Decomposition 저장\n');

%% Figure 13: RU Utilization (SA + RA)
figure('Name', 'Fig 13: RU Utilization', 'Position', [100 100 1400 800]);

for sc_idx = 1:3
    sc = scenario_names{sc_idx};
    
    %% SA-RU Utilization
    subplot(2, 3, sc_idx);
    
    m0_sa = zeros(1,3); m1_sa = zeros(1,3); m2_sa = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_sa(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.sa_utilization', num_seeds);
        [m1_sa(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.sa_utilization', num_seeds);
        [m2_sa(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.sa_utilization', num_seeds);
    end
    [base_sa, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.sa_utilization', num_seeds);
    
    plot(thold_values, m0_sa*100, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_sa*100, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerFaceColor', colors.M1);
    plot(thold_values, m2_sa*100, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_sa*100, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 2);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('SA-RU Utilization (%)');
    title(sprintf('%s: %s', sc, scenario_desc{sc_idx}));
    if sc_idx == 3, legend({'M0', 'M1(5)', 'M2', 'Baseline'}, 'Location', 'best'); end
    xlim([25 75]); ylim([0 100]); grid on;
    
    %% RA-RU Utilization
    subplot(2, 3, sc_idx + 3);
    
    m0_ra = zeros(1,3); m1_ra = zeros(1,3); m2_ra = zeros(1,3);
    for th_idx = 1:3
        th = thold_values(th_idx);
        [m0_ra(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M0', 'throughput.ra_utilization', num_seeds);
        [m1_ra(th_idx), ~] = get_metric_avg(results_m0m1, sc, th, 'M1(5)', 'throughput.ra_utilization', num_seeds);
        [m2_ra(th_idx), ~] = get_metric_avg(results_m2, sc, th, 'M2', 'throughput.ra_utilization', num_seeds);
    end
    [base_ra, ~] = get_metric_avg(results_m0m1, sc, 0, 'Baseline', 'throughput.ra_utilization', num_seeds);
    
    plot(thold_values, m0_ra*100, '-o', 'Color', colors.M0, 'LineWidth', 2, 'MarkerFaceColor', colors.M0);
    hold on;
    plot(thold_values, m1_ra*100, '-s', 'Color', colors.M1, 'LineWidth', 2, 'MarkerFaceColor', colors.M1);
    plot(thold_values, m2_ra*100, '-^', 'Color', colors.M2, 'LineWidth', 2, 'MarkerFaceColor', colors.M2);
    yline(base_ra*100, '--', 'Baseline', 'Color', colors.Baseline, 'LineWidth', 2);
    hold off;
    
    xlabel('T_{hold} (ms)'); ylabel('RA-RU Utilization (%)');
    title(sprintf('%s: RA Utilization', sc));
    xlim([25 75]); ylim([0 100]); grid on;
end
sgtitle('Figure 13: RU Utilization (SA-RU / RA-RU)', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(output_dir, 'fig13_ru_utilization.png'));
fprintf('  ✓ Figure 13: RU Utilization 저장\n');

%% 완료
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗\n');
fprintf('║                                              분석 완료                                                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝\n\n');
fprintf('  ✓ 상세 통계 테이블 출력 완료\n');
fprintf('  ✓ 13개 Figure 저장: %s/\n', output_dir);

%% ═══════════════════════════════════════════════════════════════════════════
%  Helper Functions
%  ═══════════════════════════════════════════════════════════════════════════

function [avg, sd] = get_metric_avg(results, scenario, thold_ms, method, metric_path, num_seeds)
    values = [];
    for s = 1:num_seeds
        if strcmp(method, 'Baseline')
            field_name = sprintf('%s_Baseline_s%d', scenario, s);
        elseif strcmp(method, 'M1(5)')
            field_name = sprintf('%s_T%d_M1_5_s%d', scenario, thold_ms, s);
        else
            field_name = sprintf('%s_T%d_%s_s%d', scenario, thold_ms, method, s);
        end
        
        if isfield(results.runs, field_name)
            r = results.runs.(field_name);
            parts = strsplit(metric_path, '.');
            val = r;
            valid = true;
            for p = 1:length(parts)
                if isfield(val, parts{p})
                    val = val.(parts{p});
                else
                    valid = false;
                    break;
                end
            end
            if valid && isnumeric(val)
                values(end+1) = val;
            end
        end
    end
    if isempty(values)
        avg = NaN;
        sd = NaN;
    else
        avg = mean(values);
        sd = std(values);
    end
end

function [x_sorted, cdf_values] = manual_cdf(data)
    data = data(:);
    data = data(~isnan(data) & ~isinf(data));
    n = length(data);
    if n == 0
        x_sorted = [0; 1];
        cdf_values = [0; 1];
        return;
    end
    x_sorted = sort(data);
    cdf_values = (1:n)' / n;
end