%% test_packet_timeline.m
% 패킷 처리 타임라인 시각화: Baseline vs T_hold 비교
% STA별로 한 줄에 모든 패킷 표시

clear; clc;
addpath(genpath(pwd));

%% 설정
sim_time = 10;      % 0.5초
num_stas = 20;       % 10개 STA
lambda = 50;         % 50 pkt/s
mu_on = 0.05;        % 50ms ON
rho = 0.5;
thold_value = 0.010; % 10ms
seed = 12345;

fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║     패킷 처리 타임라인 비교: Baseline vs T_hold             ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% 공통 설정
cfg = config_default();
cfg.simulation_time = sim_time;
cfg.warmup_time = 0.0;
cfg.num_stas = num_stas;
cfg.lambda = lambda;
cfg.mu_on = mu_on;
cfg.rho = rho;
cfg.mu_off = mu_on * (1 - rho) / rho;
cfg.verbose = 0;
cfg.seed = seed;

cfg.total_slots = ceil(cfg.simulation_time / cfg.slot_duration);
cfg.warmup_slots = 0;

%% 1. Baseline 실행
fprintf('Baseline 실행 중...\n');
cfg.thold_enabled = false;
cfg.thold_slots = 0;

sim_base = Simulator(cfg);
results_base = sim_base.run();
stas_base = sim_base.stas;

%% 2. T_hold 실행
fprintf('T_hold 실행 중...\n');
cfg.thold_enabled = true;
cfg.thold_value = thold_value;
cfg.thold_slots = ceil(cfg.thold_value / cfg.slot_duration);

sim_thold = Simulator(cfg);
results_thold = sim_thold.run();
stas_thold = sim_thold.stas;

%% 패킷 정보 추출
slot_duration = cfg.slot_duration;

% 구조체 배열로 저장
pkts_base = struct('sta', {}, 'arrival', {}, 'completion', {}, 'delay', {});
pkts_thold = struct('sta', {}, 'arrival', {}, 'completion', {}, 'delay', {});

for sta = 1:num_stas
    for p = 1:stas_base(sta).num_packets
        pkt = stas_base(sta).packets(p);
        if pkt.completed
            pkts_base(end+1) = struct(...
                'sta', sta, ...
                'arrival', pkt.arrival_time, ...
                'completion', pkt.completion_slot * slot_duration, ...
                'delay', (pkt.completion_slot - pkt.enqueue_slot) * slot_duration);
        end
    end
    
    for p = 1:stas_thold(sta).num_packets
        pkt = stas_thold(sta).packets(p);
        if pkt.completed
            pkts_thold(end+1) = struct(...
                'sta', sta, ...
                'arrival', pkt.arrival_time, ...
                'completion', pkt.completion_slot * slot_duration, ...
                'delay', (pkt.completion_slot - pkt.enqueue_slot) * slot_duration);
        end
    end
end

fprintf('\nBaseline: %d 패킷 완료\n', length(pkts_base));
fprintf('T_hold:   %d 패킷 완료\n\n', length(pkts_thold));

%% 시각화 1: STA별 타임라인 (Baseline vs T_hold 나란히)
figure('Position', [50, 50, 1600, 900]);

% 색상 맵
colors = lines(num_stas);

% --- Baseline ---
subplot(1, 2, 1);
hold on;

for sta = 1:num_stas
    % 해당 STA의 패킷만 필터링
    sta_idx = [pkts_base.sta] == sta;
    sta_pkts = pkts_base(sta_idx);
    
    for i = 1:length(sta_pkts)
        pkt = sta_pkts(i);
        
        % 패킷 막대 (도착 ~ 완료)
        plot([pkt.arrival, pkt.completion], [sta, sta], ...
            '-', 'Color', colors(sta,:), 'LineWidth', 3);
        
        % 도착 마커
        plot(pkt.arrival, sta, 'g|', 'MarkerSize', 8, 'LineWidth', 1.5);
    end
end

xlabel('시간 (초)', 'FontSize', 12);
ylabel('STA', 'FontSize', 12);
title(sprintf('Baseline - 평균 지연: %.2f ms', results_base.delay.mean_ms), 'FontSize', 14);
yticks(1:num_stas);
xlim([0, sim_time]);
ylim([0.5, num_stas + 0.5]);
grid on;
set(gca, 'YDir', 'reverse');

% --- T_hold ---
subplot(1, 2, 2);
hold on;

for sta = 1:num_stas
    sta_idx = [pkts_thold.sta] == sta;
    sta_pkts = pkts_thold(sta_idx);
    
    for i = 1:length(sta_pkts)
        pkt = sta_pkts(i);
        
        plot([pkt.arrival, pkt.completion], [sta, sta], ...
            '-', 'Color', colors(sta,:), 'LineWidth', 3);
        
        plot(pkt.arrival, sta, 'g|', 'MarkerSize', 8, 'LineWidth', 1.5);
    end
end

xlabel('시간 (초)', 'FontSize', 12);
ylabel('STA', 'FontSize', 12);
title(sprintf('T_{hold} (10ms) - 평균 지연: %.2f ms', results_thold.delay.mean_ms), 'FontSize', 14);
yticks(1:num_stas);
xlim([0, sim_time]);
ylim([0.5, num_stas + 0.5]);
grid on;
set(gca, 'YDir', 'reverse');

sgtitle(sprintf('패킷 처리 타임라인 (STA=%d, λ=%d pkt/s, 막대 길이 = 지연)', ...
    num_stas, lambda), 'FontSize', 16);

%% 시각화 2: 확대 비교 (처음 100ms)
figure('Position', [50, 50, 1600, 900]);

zoom_end = 0.1;  % 100ms

% --- Baseline 확대 ---
subplot(1, 2, 1);
hold on;

for sta = 1:num_stas
    sta_idx = [pkts_base.sta] == sta;
    sta_pkts = pkts_base(sta_idx);
    
    for i = 1:length(sta_pkts)
        pkt = sta_pkts(i);
        if pkt.arrival < zoom_end
            x_end = min(pkt.completion, zoom_end);
            plot([pkt.arrival, x_end], [sta, sta], ...
                '-', 'Color', colors(sta,:), 'LineWidth', 5);
            plot(pkt.arrival, sta, 'g>', 'MarkerSize', 6, 'MarkerFaceColor', 'g');
            if pkt.completion <= zoom_end
                plot(pkt.completion, sta, 'rs', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
            end
        end
    end
end

xlabel('시간 (초)', 'FontSize', 12);
ylabel('STA', 'FontSize', 12);
title(sprintf('Baseline (확대 0~%.0fms)', zoom_end*1000), 'FontSize', 14);
yticks(1:num_stas);
xlim([0, zoom_end]);
ylim([0.5, num_stas + 0.5]);
grid on;
set(gca, 'YDir', 'reverse');

% --- T_hold 확대 ---
subplot(1, 2, 2);
hold on;

for sta = 1:num_stas
    sta_idx = [pkts_thold.sta] == sta;
    sta_pkts = pkts_thold(sta_idx);
    
    for i = 1:length(sta_pkts)
        pkt = sta_pkts(i);
        if pkt.arrival < zoom_end
            x_end = min(pkt.completion, zoom_end);
            plot([pkt.arrival, x_end], [sta, sta], ...
                '-', 'Color', colors(sta,:), 'LineWidth', 5);
            plot(pkt.arrival, sta, 'g>', 'MarkerSize', 6, 'MarkerFaceColor', 'g');
            if pkt.completion <= zoom_end
                plot(pkt.completion, sta, 'rs', 'MarkerSize', 6, 'MarkerFaceColor', 'r');
            end
        end
    end
end

xlabel('시간 (초)', 'FontSize', 12);
ylabel('STA', 'FontSize', 12);
title(sprintf('T_{hold} (확대 0~%.0fms)', zoom_end*1000), 'FontSize', 14);
yticks(1:num_stas);
xlim([0, zoom_end]);
ylim([0.5, num_stas + 0.5]);
grid on;
set(gca, 'YDir', 'reverse');

% 범례
h1 = plot(nan, nan, 'g>', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
h2 = plot(nan, nan, 'rs', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
legend([h1, h2], {'도착', '완료'}, 'Location', 'southeast');

sgtitle('패킷 처리 확대 비교 (막대 길이 = 지연)', 'FontSize', 16);

%% 시각화 3: 지연 분포 + STA별 평균 지연 + Fairness
figure('Position', [100, 100, 1600, 500]);

% 지연 히스토그램
subplot(1, 4, 1);
delays_base = [pkts_base.delay] * 1000;
delays_thold = [pkts_thold.delay] * 1000;

histogram(delays_base, 20, 'FaceColor', 'b', 'FaceAlpha', 0.5);
hold on;
histogram(delays_thold, 20, 'FaceColor', 'r', 'FaceAlpha', 0.5);
xlabel('지연 (ms)');
ylabel('패킷 수');
title('지연 분포');
legend(sprintf('Baseline (%.1fms)', mean(delays_base)), ...
       sprintf('T_{hold} (%.1fms)', mean(delays_thold)));
grid on;

% CDF
subplot(1, 4, 2);
x_base = sort(delays_base);
f_base = (1:length(x_base)) / length(x_base);
x_thold = sort(delays_thold);
f_thold = (1:length(x_thold)) / length(x_thold);

plot(x_base, f_base, 'b-', 'LineWidth', 2);
hold on;
plot(x_thold, f_thold, 'r-', 'LineWidth', 2);
xlabel('지연 (ms)');
ylabel('CDF');
title('지연 CDF');
legend('Baseline', 'T_{hold}', 'Location', 'southeast');
grid on;

% STA별 평균 지연
subplot(1, 4, 3);
sta_delay_base = zeros(1, num_stas);
sta_delay_thold = zeros(1, num_stas);
sta_pkts_base = zeros(1, num_stas);
sta_pkts_thold = zeros(1, num_stas);
sta_throughput_base = zeros(1, num_stas);
sta_throughput_thold = zeros(1, num_stas);

for sta = 1:num_stas
    idx_b = [pkts_base.sta] == sta;
    idx_t = [pkts_thold.sta] == sta;
    
    sta_pkts_base(sta) = sum(idx_b);
    sta_pkts_thold(sta) = sum(idx_t);
    
    if any(idx_b)
        sta_delay_base(sta) = mean([pkts_base(idx_b).delay]) * 1000;
        sta_throughput_base(sta) = sta_pkts_base(sta) * cfg.mpdu_size * 8 / sim_time / 1e6;  % Mbps
    end
    if any(idx_t)
        sta_delay_thold(sta) = mean([pkts_thold(idx_t).delay]) * 1000;
        sta_throughput_thold(sta) = sta_pkts_thold(sta) * cfg.mpdu_size * 8 / sim_time / 1e6;
    end
end

bar_data = [sta_delay_base; sta_delay_thold]';
b = bar(bar_data);
b(1).FaceColor = 'b';
b(2).FaceColor = 'r';
xlabel('STA');
ylabel('평균 지연 (ms)');
title('STA별 평균 지연');
legend('Baseline', 'T_{hold}', 'Location', 'northwest');
grid on;

% STA별 처리율 + Jain's Fairness Index
subplot(1, 4, 4);
bar_data2 = [sta_throughput_base; sta_throughput_thold]';
b2 = bar(bar_data2);
b2(1).FaceColor = 'b';
b2(2).FaceColor = 'r';
xlabel('STA');
ylabel('처리율 (Mbps)');

% Jain's Fairness Index 계산
jain_delay_base = sum(sta_delay_base)^2 / (num_stas * sum(sta_delay_base.^2));
jain_delay_thold = sum(sta_delay_thold)^2 / (num_stas * sum(sta_delay_thold.^2));
jain_tput_base = sum(sta_throughput_base)^2 / (num_stas * sum(sta_throughput_base.^2));
jain_tput_thold = sum(sta_throughput_thold)^2 / (num_stas * sum(sta_throughput_thold.^2));

title(sprintf('STA별 처리율\nJain: B=%.3f, T=%.3f', jain_tput_base, jain_tput_thold));
legend('Baseline', 'T_{hold}', 'Location', 'northwest');
grid on;

sgtitle('지연 및 공정성 분석', 'FontSize', 14);

%% 시각화 4: Fairness 상세 분석
figure('Position', [100, 100, 1200, 400]);

% STA별 패킷 완료 수
subplot(1, 3, 1);
bar_data3 = [sta_pkts_base; sta_pkts_thold]';
b3 = bar(bar_data3);
b3(1).FaceColor = 'b';
b3(2).FaceColor = 'r';
xlabel('STA');
ylabel('완료 패킷 수');
title('STA별 완료 패킷 수');
legend('Baseline', 'T_{hold}', 'Location', 'northwest');
grid on;

% Jain's Index 비교 (막대)
subplot(1, 3, 2);
jain_data = [jain_delay_base, jain_delay_thold; jain_tput_base, jain_tput_thold];
b4 = bar(jain_data);
b4(1).FaceColor = 'b';
b4(2).FaceColor = 'r';
set(gca, 'XTickLabel', {'지연 공정성', '처리율 공정성'});
ylabel('Jain''s Fairness Index');
title('공정성 지수 비교 (1에 가까울수록 공정)');
legend('Baseline', 'T_{hold}', 'Location', 'southeast');
ylim([0, 1.1]);
grid on;

% 각 막대 위에 값 표시
for i = 1:2
    text(i-0.15, jain_data(i,1)+0.03, sprintf('%.3f', jain_data(i,1)), 'FontSize', 9, 'HorizontalAlignment', 'center');
    text(i+0.15, jain_data(i,2)+0.03, sprintf('%.3f', jain_data(i,2)), 'FontSize', 9, 'HorizontalAlignment', 'center');
end

% 지연 변동계수 (CV) 비교
subplot(1, 3, 3);
cv_delay_base = std(sta_delay_base) / mean(sta_delay_base) * 100;
cv_delay_thold = std(sta_delay_thold) / mean(sta_delay_thold) * 100;
cv_tput_base = std(sta_throughput_base) / mean(sta_throughput_base) * 100;
cv_tput_thold = std(sta_throughput_thold) / mean(sta_throughput_thold) * 100;

cv_data = [cv_delay_base, cv_delay_thold; cv_tput_base, cv_tput_thold];
b5 = bar(cv_data);
b5(1).FaceColor = 'b';
b5(2).FaceColor = 'r';
set(gca, 'XTickLabel', {'지연 CV', '처리율 CV'});
ylabel('변동계수 (%)');
title('STA간 변동계수 (낮을수록 공정)');
legend('Baseline', 'T_{hold}', 'Location', 'northeast');
grid on;

sgtitle('공정성 상세 분석', 'FontSize', 14);

%% 통계 출력
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('                     결과 비교                                 \n');
fprintf('═══════════════════════════════════════════════════════════════\n\n');

fprintf('%-20s %12s %12s %12s\n', '지표', 'Baseline', 'T_hold', '개선율');
fprintf('%s\n', repmat('-', 1, 60));

% 평균 지연
base_val = results_base.delay.mean_ms;
thold_val = results_thold.delay.mean_ms;
improve = (base_val - thold_val) / base_val * 100;
fprintf('%-20s %10.2f ms %10.2f ms %+10.1f%%\n', '평균 지연', base_val, thold_val, improve);

% P90 지연
base_val = results_base.delay.p90_ms;
thold_val = results_thold.delay.p90_ms;
improve = (base_val - thold_val) / base_val * 100;
fprintf('%-20s %10.2f ms %10.2f ms %+10.1f%%\n', 'P90 지연', base_val, thold_val, improve);

% 충돌률
base_val = results_base.uora.collision_rate * 100;
thold_val = results_thold.uora.collision_rate * 100;
if base_val > 0
    improve = (base_val - thold_val) / base_val * 100;
else
    improve = 0;
end
fprintf('%-20s %10.1f %% %10.1f %% %+10.1f%%\n', '충돌률', base_val, thold_val, improve);

% 처리율
fprintf('%-20s %9.2f Mbps %8.2f Mbps\n', '처리율', ...
    results_base.throughput.total_mbps, results_thold.throughput.total_mbps);

% 완료율
fprintf('%-20s %10.1f %% %10.1f %%\n', '완료율', ...
    results_base.packets.completion_rate*100, results_thold.packets.completion_rate*100);

% Fairness (Jain's Index)
fprintf('\n[공정성 - Jain''s Fairness Index (1에 가까울수록 공정)]\n');
fprintf('  지연 공정성:   Baseline=%.4f, T_hold=%.4f\n', jain_delay_base, jain_delay_thold);
fprintf('  처리율 공정성: Baseline=%.4f, T_hold=%.4f\n', jain_tput_base, jain_tput_thold);

% 변동계수 (CV)
fprintf('\n[STA간 변동계수 (낮을수록 공정)]\n');
fprintf('  지연 CV:   Baseline=%.1f%%, T_hold=%.1f%%\n', cv_delay_base, cv_delay_thold);
fprintf('  처리율 CV: Baseline=%.1f%%, T_hold=%.1f%%\n', cv_tput_base, cv_tput_thold);

% T_hold 통계
fprintf('\n[T_hold 통계]\n');
fprintf('  발동: %d회\n', results_thold.thold.activations);
fprintf('  Hit:  %d회 (%.1f%%)\n', results_thold.thold.hits, results_thold.thold.hit_rate*100);

fprintf('\n완료!\n');