%% run_phase1_baseline.m
% Phase 1: 베이스라인 (T_hold OFF) - 9회
%
% STA: 20, 50, 70
% rho: 0.3, 0.5, 0.7
% T_hold: OFF
%
% 예상 시간: ~30분

clear; clc;
addpath(genpath(pwd));

%% ═══════════════════════════════════════════════════════════════════
%  결과 저장 폴더 생성
%  ═══════════════════════════════════════════════════════════════════

results_dir = 'results';
phase_dir = fullfile(results_dir, 'raw', 'phase1_baseline');

if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(fullfile(results_dir, 'raw'), 'dir'), mkdir(fullfile(results_dir, 'raw')); end
if ~exist(phase_dir, 'dir'), mkdir(phase_dir); end
if ~exist(fullfile(results_dir, 'summary'), 'dir'), mkdir(fullfile(results_dir, 'summary')); end

%% ═══════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════

base_cfg = experiment_config();

sta_list = [20, 50, 70];
rho_list = [0.3, 0.5, 0.7];

total_experiments = length(sta_list) * length(rho_list);
exp_count = 0;
phase_results = [];

%% ═══════════════════════════════════════════════════════════════════
%  실험 시작
%  ═══════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 1: 베이스라인 (T_hold OFF) - %d회                      ║\n', total_experiments);
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

total_start = tic;

for sta = sta_list
    for rho = rho_list
        exp_count = exp_count + 1;
        exp_id = sprintf('B-%02d', exp_count);
        
        % 설정
        cfg = base_cfg;
        cfg.num_stas = sta;
        cfg.num_ru_ra = 1;
        cfg.num_ru_sa = cfg.num_ru_total - cfg.num_ru_ra;
        cfg.rho = rho;
        cfg.lambda = 50;
        cfg.thold_enabled = false;  % OFF
        cfg.thold_value = 0;
        
        % mu_off 계산
        cfg.mu_off = cfg.mu_on * (1 - rho) / rho;
        
        % 설정 검증 및 슬롯 변환
        cfg = validate_config(cfg);
        
        fprintf('  [%d/%d] %s: STA=%d, rho=%.1f, T_hold=OFF ... ', ...
            exp_count, total_experiments, exp_id, sta, rho);
        
        % 시뮬레이션 실행
        exp_start = tic;
        sim = Simulator(cfg);
        results = sim.run();
        elapsed = toc(exp_start);
        
        fprintf('완료 (%.1fs)\n', elapsed);
        
        % 메타 정보 추가
        results.config = cfg;
        results.exp_id = exp_id;
        results.phase = 1;
        
        % Raw 결과 저장
        filename = sprintf('%s_STA%d_rho%.1f_thold0.mat', exp_id, sta, rho);
        save(fullfile(phase_dir, filename), 'results');
        
        % 요약 저장
        phase_results = [phase_results; summarize_results(results, cfg)];
        
        % 중간 저장 (안전)
        phase_table = struct2table(phase_results);
        writetable(phase_table, fullfile(results_dir, 'summary', 'phase1_baseline.csv'));
    end
end

%% ═══════════════════════════════════════════════════════════════════
%  완료 요약
%  ═══════════════════════════════════════════════════════════════════

total_elapsed = toc(total_start);

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 1 완료                                                ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  실험: %d회                                                   ║\n', exp_count);
fprintf('║  시간: %.1f분                                                 ║\n', total_elapsed/60);
fprintf('║  평균: %.1f초/실험                                            ║\n', total_elapsed/exp_count);
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  결과 저장:                                                  ║\n');
fprintf('║  - Raw: %s/                               ║\n', phase_dir);
fprintf('║  - CSV: results/summary/phase1_baseline.csv                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

%% ═══════════════════════════════════════════════════════════════════
%  결과 미리보기
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n■ 결과 미리보기:\n');
fprintf('  ┌──────┬───────┬────────────┬──────────────┬─────────────┐\n');
fprintf('  │ STA  │  rho  │ Delay(ms)  │ Collision(%%) │   Jain      │\n');
fprintf('  ├──────┼───────┼────────────┼──────────────┼─────────────┤\n');
for i = 1:height(phase_table)
    fprintf('  │ %3d  │  %.1f  │   %6.2f   │    %5.1f     │   %.4f    │\n', ...
        phase_table.num_stas(i), phase_table.rho(i), ...
        phase_table.delay_mean_ms(i), phase_table.uora_collision_rate(i)*100, ...
        phase_table.jain_index(i));
end
fprintf('  └──────┴───────┴────────────┴──────────────┴─────────────┘\n');
