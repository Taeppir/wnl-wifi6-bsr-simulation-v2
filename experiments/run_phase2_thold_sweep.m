%% run_phase2_thold_sweep.m
% Phase 2: T_hold 값 스윕 - 20회
%
% STA: 20, 30, 50, 70
% rho: 0.5 (고정)
% T_hold: 0, 5, 10, 20, 50 ms
%
% 예상 시간: ~1시간

clear; clc;
addpath(genpath(pwd));

%% ═══════════════════════════════════════════════════════════════════
%  결과 저장 폴더 생성
%  ═══════════════════════════════════════════════════════════════════

results_dir = 'results';
phase_dir = fullfile(results_dir, 'raw', 'phase2_thold_sweep');

if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(fullfile(results_dir, 'raw'), 'dir'), mkdir(fullfile(results_dir, 'raw')); end
if ~exist(phase_dir, 'dir'), mkdir(phase_dir); end
if ~exist(fullfile(results_dir, 'summary'), 'dir'), mkdir(fullfile(results_dir, 'summary')); end

%% ═══════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════

base_cfg = experiment_config();

sta_list = [30, 50, 70];
thold_list = [10, 30, 50];  % ms

total_experiments = length(sta_list) * length(thold_list);
exp_count = 0;
phase_results = [];

%% ═══════════════════════════════════════════════════════════════════
%  실험 시작
%  ═══════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 2: T_hold 스윕 - %d회                                  ║\n', total_experiments);
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

total_start = tic;

for sta = sta_list
    for thold_ms = thold_list
        exp_count = exp_count + 1;
        exp_id = sprintf('T-%02d', exp_count);
        
        % 설정
        cfg = base_cfg;
        cfg.num_stas = sta;
        cfg.num_ru_ra = 1;
        cfg.num_ru_sa = cfg.num_ru_total - cfg.num_ru_ra;
        cfg.rho = 0.5;
        cfg.lambda = 50;
        cfg.thold_value = thold_ms / 1000;  % 초 단위로 변환
        cfg.thold_enabled = (thold_ms > 0);
        
        % mu_off 계산
        cfg.mu_off = cfg.mu_on * (1 - cfg.rho) / cfg.rho;
        
        % 설정 검증 및 슬롯 변환
        cfg = validate_config(cfg);
        
        fprintf('  [%d/%d] %s: STA=%d, T_hold=%dms ... ', ...
            exp_count, total_experiments, exp_id, sta, thold_ms);
        
        % 시뮬레이션 실행
        exp_start = tic;
        sim = Simulator(cfg);
        results = sim.run();
        elapsed = toc(exp_start);
        
        fprintf('완료 (%.1fs)\n', elapsed);
        
        % 메타 정보 추가
        results.config = cfg;
        results.exp_id = exp_id;
        results.phase = 2;
        
        % Raw 결과 저장
        filename = sprintf('%s_STA%d_thold%d.mat', exp_id, sta, thold_ms);
        save(fullfile(phase_dir, filename), 'results');
        
        % 요약 저장
        phase_results = [phase_results; summarize_results(results, cfg)];
        
        % 중간 저장 (안전)
        phase_table = struct2table(phase_results);
        writetable(phase_table, fullfile(results_dir, 'summary', 'phase2_thold_sweep.csv'));
    end
end

%% ═══════════════════════════════════════════════════════════════════
%  완료 요약
%  ═══════════════════════════════════════════════════════════════════

total_elapsed = toc(total_start);

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 2 완료                                                ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  실험: %d회                                                   ║\n', exp_count);
fprintf('║  시간: %.1f분                                                 ║\n', total_elapsed/60);
fprintf('║  평균: %.1f초/실험                                            ║\n', total_elapsed/exp_count);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

%% ═══════════════════════════════════════════════════════════════════
%  결과 미리보기
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n■ STA별 최적 T_hold:\n');
for sta = sta_list
    idx = phase_table.num_stas == sta;
    data = phase_table(idx, :);
    [min_delay, min_idx] = min(data.delay_mean_ms);
    best_thold = data.thold_ms(min_idx);
    baseline = data.delay_mean_ms(data.thold_ms == 0);
    if baseline > 0
        improvement = (baseline - min_delay) / baseline * 100;
    else
        improvement = 0;
    end
    fprintf('  STA=%d: 최적 T_hold=%dms (지연 %.2fms → %.2fms, 개선율 %.1f%%)\n', ...
        sta, best_thold, baseline, min_delay, improvement);
end
