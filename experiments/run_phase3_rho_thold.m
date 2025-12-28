%% run_phase3_rho_thold.m
% Phase 3: rho × T_hold 상호작용 - 32회
%
% STA: 20, 50
% rho: 0.2, 0.4, 0.6, 0.8
% T_hold: 0, 10, 20, 50 ms
%
% 예상 시간: ~1.5시간

clear; clc;
addpath(genpath(pwd));

%% ═══════════════════════════════════════════════════════════════════
%  결과 저장 폴더 생성
%  ═══════════════════════════════════════════════════════════════════

results_dir = 'results';
phase_dir = fullfile(results_dir, 'raw', 'phase3_rho_thold');

if ~exist(results_dir, 'dir'), mkdir(results_dir); end
if ~exist(fullfile(results_dir, 'raw'), 'dir'), mkdir(fullfile(results_dir, 'raw')); end
if ~exist(phase_dir, 'dir'), mkdir(phase_dir); end
if ~exist(fullfile(results_dir, 'summary'), 'dir'), mkdir(fullfile(results_dir, 'summary')); end

%% ═══════════════════════════════════════════════════════════════════
%  실험 설정
%  ═══════════════════════════════════════════════════════════════════

base_cfg = experiment_config();

sta_list = [20, 50];
rho_list = [0.2, 0.4, 0.6, 0.8];
thold_list = [0, 10, 20, 50];  % ms

total_experiments = length(sta_list) * length(rho_list) * length(thold_list);
exp_count = 0;
phase_results = [];

%% ═══════════════════════════════════════════════════════════════════
%  실험 시작
%  ═══════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 3: rho × T_hold 상호작용 - %d회                        ║\n', total_experiments);
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

total_start = tic;

for sta = sta_list
    fprintf('━━━ STA = %d ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n', sta);
    
    for rho = rho_list
        for thold_ms = thold_list
            exp_count = exp_count + 1;
            exp_id = sprintf('P3-%02d', exp_count);
            
            % 설정
            cfg = base_cfg;
            cfg.num_stas = sta;
            cfg.num_ru_ra = 1;
            cfg.num_ru_sa = cfg.num_ru_total - cfg.num_ru_ra;
            cfg.rho = rho;
            cfg.lambda = 50;
            cfg.thold_value = thold_ms / 1000;  % 초 단위로 변환
            cfg.thold_enabled = (thold_ms > 0);
            
            % mu_off 계산
            cfg.mu_off = cfg.mu_on * (1 - rho) / rho;
            
            % 설정 검증 및 슬롯 변환
            cfg = validate_config(cfg);
            
            fprintf('  [%d/%d] %s: STA=%d, rho=%.1f, T_hold=%dms ... ', ...
                exp_count, total_experiments, exp_id, sta, rho, thold_ms);
            
            % 시뮬레이션 실행
            exp_start = tic;
            sim = Simulator(cfg);
            results = sim.run();
            elapsed = toc(exp_start);
            
            fprintf('완료 (%.1fs)\n', elapsed);
            
            % 메타 정보 추가
            results.config = cfg;
            results.exp_id = exp_id;
            results.phase = 3;
            
            % Raw 결과 저장
            filename = sprintf('%s_STA%d_rho%.1f_thold%d.mat', exp_id, sta, rho, thold_ms);
            save(fullfile(phase_dir, filename), 'results');
            
            % 요약 저장
            phase_results = [phase_results; summarize_results(results, cfg)];
            
            % 중간 저장 (안전)
            phase_table = struct2table(phase_results);
            writetable(phase_table, fullfile(results_dir, 'summary', 'phase3_rho_thold.csv'));
        end
    end
end

%% ═══════════════════════════════════════════════════════════════════
%  완료 요약
%  ═══════════════════════════════════════════════════════════════════

total_elapsed = toc(total_start);

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║  Phase 3 완료                                                ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  실험: %d회                                                   ║\n', exp_count);
fprintf('║  시간: %.1f분                                                 ║\n', total_elapsed/60);
fprintf('║  평균: %.1f초/실험                                            ║\n', total_elapsed/exp_count);
fprintf('╚══════════════════════════════════════════════════════════════╝\n');

%% ═══════════════════════════════════════════════════════════════════
%  결과 미리보기: Trade-off 영역 분석
%  ═══════════════════════════════════════════════════════════════════

fprintf('\n■ Trade-off 영역 분석:\n');
for sta = sta_list
    fprintf('  STA=%d:\n', sta);
    idx = phase_table.num_stas == sta;
    data = phase_table(idx, :);
    
    for rho = rho_list
        rho_idx = data.rho == rho;
        rho_data = data(rho_idx, :);
        baseline = rho_data.delay_mean_ms(rho_data.thold_ms == 0);
        
        [min_delay, min_idx] = min(rho_data.delay_mean_ms);
        best_thold = rho_data.thold_ms(min_idx);
        
        if baseline > 0
            improvement = (baseline - min_delay) / baseline * 100;
        else
            improvement = 0;
        end
        
        if improvement > 5
            status = '✅ 효과적';
        elseif improvement > -5
            status = '➖ 미미';
        else
            status = '❌ 손해';
        end
        
        fprintf('    rho=%.1f: %s (최적 T_hold=%dms, 개선율 %.1f%%)\n', ...
            rho, status, best_thold, improvement);
    end
end
