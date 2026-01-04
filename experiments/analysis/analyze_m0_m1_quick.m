%% analyze_m1_quick.m
% M0 vs M1 max_phantom 탐색 결과 분석 및 시각화
%
% - 저장된 결과 (.mat) 로드
% - 전체 지표 텍스트 출력
% - 시각화 (Figure 생성)
% - 시뮬레이션 실행 없음

clear; clc; close all;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║       M0 vs M1 max_phantom 탐색 결과 분석 및 시각화               ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  결과 로드
%  ═══════════════════════════════════════════════════════════════════════════

input_file = 'results/m1_quick/results.mat';

if ~exist(input_file, 'file')
    error('결과 파일이 없습니다: %s\n먼저 run_m1_quick 실행하세요.', input_file);
end

fprintf('[결과 로드] %s\n', input_file);
load(input_file, 'results');

% 메타데이터 출력
fprintf('\n[메타데이터]\n');
fprintf('  Scenario: %s (λ=%d, ρ=%.2f)\n', results.meta.scenario.name, ...
    results.meta.scenario.lambda, results.meta.scenario.rho);
fprintf('  T_hold: %dms\n', results.meta.thold_ms);
fprintf('  Seed: %d\n', results.meta.seed);
fprintf('  Sim time: %d초\n', results.meta.sim_time);
fprintf('  Timestamp: %s\n', string(results.meta.timestamp));

% 결과 배열 구성
all_results = {results.baseline};
labels = {'Baseline'};
fields = fieldnames(results);
for i = 1:length(fields)
    if ~ismember(fields{i}, {'baseline', 'labels', 'meta'}) && isstruct(results.(fields{i}))
        all_results{end+1} = results.(fields{i});
        labels{end+1} = results.(fields{i}).label;
    end
end
num_cases = length(all_results);

fprintf('  Cases: %s\n\n', strjoin(labels, ', '));

%% ═══════════════════════════════════════════════════════════════════════════
%  전체 지표 텍스트 출력 (ALL METRICS)
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║                 전체 지표 텍스트 출력 (ALL METRICS)               ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n');

for i = 1:num_cases
    r = all_results{i};
    
    fprintf('\n');
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('  %s\n', r.label);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    % [1] packets
    fprintf('\n[1. packets]\n');
    fprintf('  generated: %d, completed: %d, completion_rate: %.4f (%.2f%%)\n', ...
        r.packets.generated, r.packets.completed, r.packets.completion_rate, r.packets.completion_rate*100);
    
    % [2] delay
    fprintf('\n[2. delay]\n');
    fprintf('  mean: %.4f, std: %.4f, min: %.4f, p10: %.4f, p50: %.4f, p90: %.4f, p99: %.4f, max: %.4f\n', ...
        r.delay.mean_ms, r.delay.std_ms, r.delay.min_ms, r.delay.p10_ms, ...
        r.delay.p50_ms, r.delay.p90_ms, r.delay.p99_ms, r.delay.max_ms);
    
    % [3] delay_decomp
    fprintf('\n[3. delay_decomp]\n');
    fprintf('  initial_wait: mean=%.4f, std=%.4f, p90=%.4f\n', ...
        r.delay_decomp.initial_wait.mean_ms, r.delay_decomp.initial_wait.std_ms, r.delay_decomp.initial_wait.p90_ms);
    fprintf('  uora_contention: mean=%.4f, std=%.4f, p90=%.4f, mean_when_used=%.4f\n', ...
        r.delay_decomp.uora_contention.mean_ms, r.delay_decomp.uora_contention.std_ms, ...
        r.delay_decomp.uora_contention.p90_ms, r.delay_decomp.uora_contention.mean_when_used_ms);
    fprintf('  sa_wait: mean=%.4f, std=%.4f, p90=%.4f\n', ...
        r.delay_decomp.sa_wait.mean_ms, r.delay_decomp.sa_wait.std_ms, r.delay_decomp.sa_wait.p90_ms);
    
    % [4] pkt_class
    fprintf('\n[4. pkt_class]\n');
    fprintf('  uora_skipped: cnt=%d, ratio=%.4f, mean=%.4f, std=%.4f, min=%.4f, p10=%.4f, p50=%.4f, p90=%.4f, p99=%.4f, max=%.4f\n', ...
        r.pkt_class.uora_skipped.count, r.pkt_class.uora_skipped.ratio, ...
        r.pkt_class.uora_skipped.mean_ms, r.pkt_class.uora_skipped.std_ms, ...
        r.pkt_class.uora_skipped.min_ms, r.pkt_class.uora_skipped.p10_ms, ...
        r.pkt_class.uora_skipped.p50_ms, r.pkt_class.uora_skipped.p90_ms, ...
        r.pkt_class.uora_skipped.p99_ms, r.pkt_class.uora_skipped.max_ms);
    fprintf('  uora_used: cnt=%d, ratio=%.4f, mean=%.4f, std=%.4f, min=%.4f, p10=%.4f, p50=%.4f, p90=%.4f, p99=%.4f, max=%.4f\n', ...
        r.pkt_class.uora_used.count, r.pkt_class.uora_used.ratio, ...
        r.pkt_class.uora_used.mean_ms, r.pkt_class.uora_used.std_ms, ...
        r.pkt_class.uora_used.min_ms, r.pkt_class.uora_used.p10_ms, ...
        r.pkt_class.uora_used.p50_ms, r.pkt_class.uora_used.p90_ms, ...
        r.pkt_class.uora_used.p99_ms, r.pkt_class.uora_used.max_ms);
    fprintf('  thold_hit: cnt=%d, ratio=%.4f, mean=%.4f, std=%.4f, min=%.4f, p10=%.4f, p50=%.4f, p90=%.4f, p99=%.4f, max=%.4f\n', ...
        r.pkt_class.thold_hit.count, r.pkt_class.thold_hit.ratio, ...
        r.pkt_class.thold_hit.mean_ms, r.pkt_class.thold_hit.std_ms, ...
        r.pkt_class.thold_hit.min_ms, r.pkt_class.thold_hit.p10_ms, ...
        r.pkt_class.thold_hit.p50_ms, r.pkt_class.thold_hit.p90_ms, ...
        r.pkt_class.thold_hit.p99_ms, r.pkt_class.thold_hit.max_ms);
    fprintf('  sa_queue: cnt=%d, ratio=%.4f, mean=%.4f, std=%.4f, min=%.4f, p10=%.4f, p50=%.4f, p90=%.4f, p99=%.4f, max=%.4f\n', ...
        r.pkt_class.sa_queue.count, r.pkt_class.sa_queue.ratio, ...
        r.pkt_class.sa_queue.mean_ms, r.pkt_class.sa_queue.std_ms, ...
        r.pkt_class.sa_queue.min_ms, r.pkt_class.sa_queue.p10_ms, ...
        r.pkt_class.sa_queue.p50_ms, r.pkt_class.sa_queue.p90_ms, ...
        r.pkt_class.sa_queue.p99_ms, r.pkt_class.sa_queue.max_ms);
    fprintf('  ra_tx: cnt=%d, ratio=%.4f, mean=%.4f, std=%.4f, min=%.4f, p10=%.4f, p50=%.4f, p90=%.4f, p99=%.4f, max=%.4f\n', ...
        r.pkt_class.ra_tx.count, r.pkt_class.ra_tx.ratio, ...
        r.pkt_class.ra_tx.mean_ms, r.pkt_class.ra_tx.std_ms, ...
        r.pkt_class.ra_tx.min_ms, r.pkt_class.ra_tx.p10_ms, ...
        r.pkt_class.ra_tx.p50_ms, r.pkt_class.ra_tx.p90_ms, ...
        r.pkt_class.ra_tx.p99_ms, r.pkt_class.ra_tx.max_ms);
    fprintf('  sa_tx: cnt=%d, ratio=%.4f, mean=%.4f, std=%.4f, min=%.4f, p10=%.4f, p50=%.4f, p90=%.4f, p99=%.4f, max=%.4f\n', ...
        r.pkt_class.sa_tx.count, r.pkt_class.sa_tx.ratio, ...
        r.pkt_class.sa_tx.mean_ms, r.pkt_class.sa_tx.std_ms, ...
        r.pkt_class.sa_tx.min_ms, r.pkt_class.sa_tx.p10_ms, ...
        r.pkt_class.sa_tx.p50_ms, r.pkt_class.sa_tx.p90_ms, ...
        r.pkt_class.sa_tx.p99_ms, r.pkt_class.sa_tx.max_ms);
    
    % [5] thold
    fprintf('\n[5. thold]\n');
    if isfield(r, 'thold') && isfield(r.thold, 'activations') && r.thold.activations > 0
        fprintf('  activations: %d, hits: %d, hit_rate: %.4f\n', ...
            r.thold.activations, r.thold.hits, r.thold.hit_rate);
        fprintf('  expirations: %d, clean_exp: %d, exp_with_data: %d\n', ...
            r.thold.expirations, r.thold.clean_exp, r.thold.exp_with_data);
        fprintf('  phantoms: %d, phantom_per_activation: %.4f, wasted_ms: %.4f\n', ...
            r.thold.phantoms, r.thold.phantom_per_activation, r.thold.wasted_ms);
    else
        fprintf('  (T_hold 비활성)\n');
    end
    
    % [6] uora
    fprintf('\n[6. uora]\n');
    fprintf('  total_success: %d, total_collision: %d, total_collision_slots: %d, total_idle: %d\n', ...
        r.uora.total_success, r.uora.total_collision, r.uora.total_collision_slots, r.uora.total_idle);
    fprintf('  total_attempts: %d, total_ra_slots: %d\n', r.uora.total_attempts, r.uora.total_ra_slots);
    fprintf('  success_rate: %.4f, collision_rate: %.4f, collision_slot_rate: %.4f, idle_rate: %.4f\n', ...
        r.uora.success_rate, r.uora.collision_rate, r.uora.collision_slot_rate, r.uora.idle_rate);
    fprintf('  avg_collision_size: %.4f, collisions_per_packet: %.4f\n', ...
        r.uora.avg_collision_size, r.uora.collisions_per_packet);
    
    % [7] throughput
    fprintf('\n[7. throughput]\n');
    fprintf('  total_mbps: %.4f, ra_utilization: %.4f, sa_utilization: %.4f\n', ...
        r.throughput.total_mbps, r.throughput.ra_utilization, r.throughput.sa_utilization);
    fprintf('  sa_phantom_rate: %.4f, sa_phantom_count: %d, channel_utilization: %.4f\n', ...
        r.throughput.sa_phantom_rate, r.throughput.sa_phantom_count, r.throughput.channel_utilization);
    
    % [8] fairness
    fprintf('\n[8. fairness]\n');
    fprintf('  jain_index: %.6f, cov: %.6f, min_max_ratio: %.6f\n', ...
        r.fairness.jain_index, r.fairness.cov, r.fairness.min_max_ratio);
    
    % [9] bsr
    fprintf('\n[9. bsr]\n');
    fprintf('  explicit_count: %d, implicit_count: %d, explicit_ratio: %.4f\n', ...
        r.bsr.explicit_count, r.bsr.implicit_count, r.bsr.explicit_ratio);
    
    % [10] tf
    fprintf('\n[10. tf]\n');
    fprintf('  count: %d, period_slots: %d, period_ms: %.4f\n', ...
        r.tf.count, r.tf.period_slots, r.tf.period_ms);
end

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 1: 지연 통계
%  ═══════════════════════════════════════════════════════════════════════════

fprintf('\n[시각화 생성 중...]\n');

fig1 = figure('Position', [50, 50, 1600, 900], 'Name', 'Figure 1: 지연 통계');

% 1-1. 전체 지연 통계
subplot(2, 3, 1);
data = zeros(num_cases, 8);
for i = 1:num_cases
    r = all_results{i};
    data(i, :) = [r.delay.mean_ms, r.delay.std_ms, r.delay.min_ms, ...
                  r.delay.p10_ms, r.delay.p50_ms, r.delay.p90_ms, ...
                  r.delay.p99_ms, r.delay.max_ms];
end
bar(data);
set(gca, 'XTickLabel', labels);
ylabel('Delay (ms)');
title('전체 지연 통계');
legend('Mean', 'Std', 'Min', 'P10', 'P50', 'P90', 'P99', 'Max', 'Location', 'northwest');
grid on;

% 1-2. 지연 CDF
subplot(2, 3, 2);
hold on;
colors = lines(num_cases);
for i = 1:num_cases
    r = all_results{i};
    sorted_data = sort(r.delay.all_ms);
    n = length(sorted_data);
    plot(sorted_data, (1:n)/n, '-', 'LineWidth', 2, 'Color', colors(i,:), 'DisplayName', labels{i});
end
xlabel('Delay (ms)');
ylabel('CDF');
title('지연 CDF');
legend('Location', 'southeast');
grid on;
xlim([0, min(500, max(cellfun(@(r) r.delay.p99_ms, all_results)) * 1.2)]);

% 1-3. 지연 분해
subplot(2, 3, 3);
decomp_data = zeros(num_cases, 3);
for i = 1:num_cases
    r = all_results{i};
    decomp_data(i, :) = [r.delay_decomp.initial_wait.mean_ms, ...
                         r.delay_decomp.uora_contention.mean_ms, ...
                         r.delay_decomp.sa_wait.mean_ms];
end
bar(decomp_data, 'stacked');
set(gca, 'XTickLabel', labels);
ylabel('Delay (ms)');
title('지연 분해');
legend('Initial Wait', 'UORA', 'SA Wait', 'Location', 'northwest');
grid on;

% 1-4. UORA Skipped vs Used
subplot(2, 3, 4);
skip_data = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    skip_data(i, :) = [r.pkt_class.uora_skipped.mean_ms, r.pkt_class.uora_used.mean_ms];
end
bar(skip_data);
set(gca, 'XTickLabel', labels);
ylabel('Mean Delay (ms)');
title('UORA Skipped vs Used');
legend('Skipped', 'Used', 'Location', 'northwest');
grid on;

% 1-5. T_hold Hit vs SA Queue
subplot(2, 3, 5);
reason_data = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    reason_data(i, :) = [r.pkt_class.thold_hit.mean_ms, r.pkt_class.sa_queue.mean_ms];
end
bar(reason_data);
set(gca, 'XTickLabel', labels);
ylabel('Mean Delay (ms)');
title('스킵 이유별 (T\_hold Hit vs SA Queue)');
legend('T\_hold Hit', 'SA Queue', 'Location', 'northwest');
grid on;

% 1-6. RA vs SA TX
subplot(2, 3, 6);
tx_data = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    tx_data(i, :) = [r.pkt_class.ra_tx.mean_ms, r.pkt_class.sa_tx.mean_ms];
end
bar(tx_data);
set(gca, 'XTickLabel', labels);
ylabel('Mean Delay (ms)');
title('전송 타입별 (RA vs SA)');
legend('RA-RU', 'SA-RU', 'Location', 'northwest');
grid on;

sgtitle('Figure 1: 지연 통계', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig1, 'results/m1_quick/fig1_delay.png');
fprintf('  저장: fig1_delay.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 2: T_hold 통계
%  ═══════════════════════════════════════════════════════════════════════════

fig2 = figure('Position', [100, 100, 1400, 500], 'Name', 'Figure 2: T_hold 통계');

% 2-1. Activations / Hits / Expirations
subplot(1, 3, 1);
thold_data = zeros(num_cases, 3);
for i = 1:num_cases
    r = all_results{i};
    if isfield(r, 'thold') && isfield(r.thold, 'activations')
        thold_data(i, :) = [r.thold.activations, r.thold.hits, r.thold.expirations];
    end
end
bar(thold_data);
set(gca, 'XTickLabel', labels);
ylabel('Count');
title('Activations / Hits / Expirations');
legend('Activations', 'Hits', 'Expirations', 'Location', 'northwest');
grid on;

% 2-2. Hit Rate & Phantom per Activation
subplot(1, 3, 2);
hit_phantom = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    if isfield(r, 'thold') && isfield(r.thold, 'hit_rate') && isfield(r.thold, 'phantom_per_activation')
        hit_phantom(i, :) = [r.thold.hit_rate * 100, r.thold.phantom_per_activation * 10];
    else
        hit_phantom(i, :) = [0, 0];
    end
end
bar(hit_phantom);
set(gca, 'XTickLabel', labels);
ylabel('Value');
title('Hit Rate (%) & Phantom/Act (×10)');
legend('Hit Rate (%)', 'Phantom/Act ×10', 'Location', 'northwest');
grid on;

% 2-3. Phantoms & Clean/WithData Expirations
subplot(1, 3, 3);
exp_data = zeros(num_cases, 3);
for i = 1:num_cases
    r = all_results{i};
    if isfield(r, 'thold') && isfield(r.thold, 'phantoms')
        exp_data(i, :) = [r.thold.phantoms, r.thold.clean_exp, r.thold.exp_with_data];
    end
end
bar(exp_data);
set(gca, 'XTickLabel', labels);
ylabel('Count');
title('Phantoms & Expiration 분류');
legend('Phantoms', 'Clean Exp', 'Exp with Data', 'Location', 'northwest');
grid on;

sgtitle('Figure 2: T\_hold 통계', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig2, 'results/m1_quick/fig2_thold.png');
fprintf('  저장: fig2_thold.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 3: 패킷 분류
%  ═══════════════════════════════════════════════════════════════════════════

fig3 = figure('Position', [150, 150, 1400, 500], 'Name', 'Figure 3: 패킷 분류');

% 3-1. 패킷 분류 비율 (3분류)
subplot(1, 3, 1);
ratio_data = zeros(num_cases, 3);
for i = 1:num_cases
    r = all_results{i};
    ratio_data(i, :) = [r.pkt_class.thold_hit.ratio*100, ...
                        r.pkt_class.sa_queue.ratio*100, ...
                        r.pkt_class.uora_used.ratio*100];
end
bar(ratio_data, 'stacked');
set(gca, 'XTickLabel', labels);
ylabel('Ratio (%)');
title('패킷 분류 비율');
legend('T\_hold Hit', 'SA Queue', 'UORA Used', 'Location', 'southeast');
ylim([0, 100]);
grid on;

% 3-2. 전송 타입 비율
subplot(1, 3, 2);
tx_ratio = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    tx_ratio(i, :) = [r.pkt_class.ra_tx.ratio*100, r.pkt_class.sa_tx.ratio*100];
end
bar(tx_ratio, 'stacked');
set(gca, 'XTickLabel', labels);
ylabel('Ratio (%)');
title('전송 타입 비율 (RA vs SA)');
legend('RA-RU', 'SA-RU', 'Location', 'southeast');
ylim([0, 100]);
grid on;

% 3-3. 패킷 수 비교
subplot(1, 3, 3);
pkt_count = zeros(num_cases, 3);
for i = 1:num_cases
    r = all_results{i};
    pkt_count(i, :) = [r.pkt_class.thold_hit.count, ...
                       r.pkt_class.sa_queue.count, ...
                       r.pkt_class.uora_used.count];
end
bar(pkt_count, 'stacked');
set(gca, 'XTickLabel', labels);
ylabel('Packet Count');
title('패킷 분류별 수');
legend('T\_hold Hit', 'SA Queue', 'UORA Used', 'Location', 'northwest');
grid on;

sgtitle('Figure 3: 패킷 분류', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig3, 'results/m1_quick/fig3_pkt_class.png');
fprintf('  저장: fig3_pkt_class.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 4: UORA 통계
%  ═══════════════════════════════════════════════════════════════════════════

fig4 = figure('Position', [200, 200, 1400, 500], 'Name', 'Figure 4: UORA 통계');

% 4-1. RA-RU 결과
subplot(1, 3, 1);
ra_data = zeros(num_cases, 3);
for i = 1:num_cases
    r = all_results{i};
    ra_data(i, :) = [r.uora.total_success, r.uora.total_collision_slots, r.uora.total_idle];
end
bar(ra_data, 'stacked');
set(gca, 'XTickLabel', labels);
ylabel('RA-RU Slots');
title('RA-RU 결과');
legend('Success', 'Collision', 'Idle', 'Location', 'northwest');
grid on;

% 4-2. RA-RU 비율
subplot(1, 3, 2);
ra_rate = zeros(num_cases, 3);
for i = 1:num_cases
    r = all_results{i};
    ra_rate(i, :) = [r.uora.success_rate*100, r.uora.collision_slot_rate*100, r.uora.idle_rate*100];
end
bar(ra_rate);
set(gca, 'XTickLabel', labels);
ylabel('Rate (%)');
title('RA-RU 상태 비율');
legend('Success', 'Collision', 'Idle', 'Location', 'northwest');
grid on;

% 4-3. Collision 상세
subplot(1, 3, 3);
coll_data = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    coll_data(i, :) = [r.uora.collision_rate*100, r.uora.avg_collision_size];
end
yyaxis left;
bar(coll_data(:,1));
ylabel('Collision Rate (%)');
yyaxis right;
plot(1:num_cases, coll_data(:,2), 'ko-', 'LineWidth', 2, 'MarkerSize', 10);
ylabel('Avg Collision Size');
set(gca, 'XTickLabel', labels);
title('Collision 상세');
grid on;

sgtitle('Figure 4: UORA 통계', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig4, 'results/m1_quick/fig4_uora.png');
fprintf('  저장: fig4_uora.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 5: 처리율 & 공정성 & BSR
%  ═══════════════════════════════════════════════════════════════════════════

fig5 = figure('Position', [250, 250, 1600, 500], 'Name', 'Figure 5: 처리율 & 공정성 & BSR');

% 5-1. Throughput
subplot(1, 4, 1);
thru_data = zeros(num_cases, 1);
for i = 1:num_cases
    r = all_results{i};
    thru_data(i) = r.throughput.total_mbps;
end
bar(thru_data);
set(gca, 'XTickLabel', labels);
xtickangle(45);
ylabel('Throughput (Mbps)');
title('총 처리율');
grid on;

% 5-2. Channel Utilization & SA Phantom Rate
subplot(1, 4, 2);
util_data = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    util_data(i, :) = [r.throughput.channel_utilization*100, r.throughput.sa_phantom_rate*100];
end
bar(util_data);
set(gca, 'XTickLabel', labels);
xtickangle(45);
ylabel('Rate (%)');
title('Channel Util. & SA Phantom Rate');
legend('Channel Util.', 'SA Phantom', 'Location', 'northwest');
grid on;

% 5-3. Fairness
subplot(1, 4, 3);
fair_data = zeros(num_cases, 1);
for i = 1:num_cases
    r = all_results{i};
    fair_data(i) = r.fairness.jain_index;
end
bar(fair_data);
set(gca, 'XTickLabel', labels);
xtickangle(45);
ylabel('Jain''s Fairness Index');
title('공정성');
ylim([0.9, 1.0]);
grid on;

% 5-4. BSR (Explicit vs Implicit)
subplot(1, 4, 4);
bsr_data = zeros(num_cases, 2);
for i = 1:num_cases
    r = all_results{i};
    bsr_data(i, :) = [r.bsr.explicit_count, r.bsr.implicit_count];
end
bar(bsr_data, 'stacked');
set(gca, 'XTickLabel', labels);
xtickangle(45);
ylabel('BSR Count');
title('BSR (Explicit vs Implicit)');
legend('Explicit', 'Implicit', 'Location', 'northwest');
grid on;

sgtitle('Figure 5: 처리율 & 공정성 & BSR', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig5, 'results/m1_quick/fig5_throughput_fairness_bsr.png');
fprintf('  저장: fig5_throughput_fairness_bsr.png\n');

%% ═══════════════════════════════════════════════════════════════════════════
%  Figure 6: Trade-off
%  ═══════════════════════════════════════════════════════════════════════════

fig6 = figure('Position', [300, 300, 1000, 400], 'Name', 'Figure 6: Trade-off');

% 6-1. Delay vs Phantom
subplot(1, 2, 1);
hold on;
for i = 2:num_cases
    r = all_results{i};
    if isfield(r, 'thold') && isfield(r.thold, 'phantoms')
        scatter(r.thold.phantoms, r.delay.mean_ms, 150, 'filled');
        text(r.thold.phantoms * 1.02, r.delay.mean_ms, labels{i}, 'FontSize', 10);
    end
end
yline(all_results{1}.delay.mean_ms, 'k--', 'LineWidth', 2);
text(1000, all_results{1}.delay.mean_ms + 5, 'Baseline', 'FontSize', 10);
xlabel('Phantom Count');
ylabel('Mean Delay (ms)');
title('지연 vs Phantom');
grid on;

% 6-2. Hit Rate vs Delay
subplot(1, 2, 2);
hold on;
for i = 2:num_cases
    r = all_results{i};
    if isfield(r, 'thold') && isfield(r.thold, 'hit_rate')
        scatter(r.thold.hit_rate * 100, r.delay.mean_ms, 150, 'filled');
        text(r.thold.hit_rate * 100 + 1, r.delay.mean_ms, labels{i}, 'FontSize', 10);
    end
end
yline(all_results{1}.delay.mean_ms, 'k--', 'LineWidth', 2);
text(5, all_results{1}.delay.mean_ms + 5, 'Baseline', 'FontSize', 10);
xlabel('Hit Rate (%)');
ylabel('Mean Delay (ms)');
title('Hit Rate vs 지연');
grid on;

sgtitle('Figure 6: Trade-off 분석', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig6, 'results/m1_quick/fig6_tradeoff.png');
fprintf('  저장: fig6_tradeoff.png\n');

fprintf('\n분석 완료! Figure 6개 저장됨.\n');