%% visualize_onoff_vs_buffer_empty.m
% On/Off 구간과 버퍼가 비는 구간의 관계 시각화
%
% 목적: T_hold 값 설정 근거 분석
%   - On 구간 (패킷 생성) vs Off 구간 (패킷 없음)
%   - 버퍼가 비는 시점과 다음 패킷 도착까지의 시간
%
% 출력:
%   - Figure 1: On/Off 구간 + 버퍼 빈 구간 타임라인 (단말별)
%   - Figure 2: 버퍼 빈 기간 분포 히스토그램

clear; clc;
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
fprintf('║        On/Off 구간 vs 버퍼 빈 구간 분석                           ║\n');
fprintf('╚══════════════════════════════════════════════════════════════════╝\n\n');

%% 설정
sim_time = 20;  % 2초 (시각화용으로 짧게)
num_stas = 20;  % 5개 단말

% 트래픽 파라미터 (VoIP-like)
lambda = 100;       % On 구간 중 패킷 도착률
rho = 0.3;          % duty cycle
mu_off = 0.050;     % 50ms
mu_on = rho * mu_off / (1 - rho);  % ~21ms
pareto_alpha = 1.5;

fprintf('[설정]\n');
fprintf('  시뮬레이션 시간: %.1f초\n', sim_time);
fprintf('  단말 수: %d\n', num_stas);
fprintf('  트래픽: λ=%d, ρ=%.2f, μ_on=%.1fms, μ_off=%.1fms\n', ...
    lambda, rho, mu_on*1000, mu_off*1000);

%% 트래픽 생성 및 버퍼 시뮬레이션
rng(1234);  % 재현성

% 결과 저장
sta_data = struct();

for sta_idx = 1:num_stas
    fprintf('\n[STA %d] 트래픽 생성 중...\n', sta_idx);
    
    % On/Off 구간 생성
    on_periods = [];  % [start, end]
    off_periods = []; % [start, end]
    
    current_time = 0;
    in_on = false;
    
    % 초기 상태 (Off로 시작)
    while current_time < sim_time
        if ~in_on
            % Off 구간
            off_duration = (mu_off) * (rand^(-1/pareto_alpha));
            off_duration = min(off_duration, 1);  % 최대 1초 제한
            off_start = current_time;
            off_end = min(current_time + off_duration, sim_time);
            off_periods = [off_periods; off_start, off_end];
            current_time = off_end;
            in_on = true;
        else
            % On 구간
            on_duration = (mu_on) * (rand^(-1/pareto_alpha));
            on_duration = min(on_duration, 1);
            on_start = current_time;
            on_end = min(current_time + on_duration, sim_time);
            on_periods = [on_periods; on_start, on_end];
            current_time = on_end;
            in_on = false;
        end
    end
    
    % On 구간 내 패킷 생성
    packets = [];
    for i = 1:size(on_periods, 1)
        t = on_periods(i, 1);
        t_end = on_periods(i, 2);
        while t < t_end
            inter_arrival = -log(rand) / lambda;  % exponential distribution
            t = t + inter_arrival;
            if t < t_end
                packets = [packets; t];
            end
        end
    end
    packets = sort(packets);
    
    fprintf('  On 구간: %d개, Off 구간: %d개\n', size(on_periods,1), size(off_periods,1));
    fprintf('  생성된 패킷: %d개\n', length(packets));
    
    % 버퍼 시뮬레이션 (간단 버전)
    % 가정: TF 주기 2.772ms, 매 TF에서 1패킷 전송 가능
    tf_period = 0.002772;
    buffer_empty_periods = [];  % [start, end]
    
    buffer = 0;
    pkt_idx = 1;
    buffer_empty_start = 0;
    is_empty = true;
    
    for t = 0:tf_period:sim_time
        % 패킷 도착 처리
        while pkt_idx <= length(packets) && packets(pkt_idx) <= t
            if is_empty && buffer == 0
                % 버퍼가 비어있다가 패킷 도착
                if buffer_empty_start > 0
                    buffer_empty_periods = [buffer_empty_periods; buffer_empty_start, packets(pkt_idx)];
                end
                is_empty = false;
            end
            buffer = buffer + 1;
            pkt_idx = pkt_idx + 1;
        end
        
        % 전송 처리 (매 TF에서 1패킷)
        if buffer > 0
            buffer = buffer - 1;
            if buffer == 0
                buffer_empty_start = t;
                is_empty = true;
            end
        end
    end
    
    % 마지막 빈 구간
    if is_empty && buffer_empty_start > 0
        buffer_empty_periods = [buffer_empty_periods; buffer_empty_start, sim_time];
    end
    
    fprintf('  버퍼 빈 구간: %d개\n', size(buffer_empty_periods, 1));
    
    % 저장
    sta_data(sta_idx).on_periods = on_periods;
    sta_data(sta_idx).off_periods = off_periods;
    sta_data(sta_idx).packets = packets;
    sta_data(sta_idx).buffer_empty_periods = buffer_empty_periods;
end

%% Figure 1: 타임라인 시각화
figure('Name', 'On/Off vs Buffer Empty', 'Position', [100 100 1400 800]);

for sta_idx = 1:num_stas
    subplot(num_stas, 1, sta_idx);
    
    y_base = 0;
    y_height = 1;
    
    % Off 구간 (회색 배경)
    for i = 1:size(sta_data(sta_idx).off_periods, 1)
        t_start = sta_data(sta_idx).off_periods(i, 1);
        t_end = sta_data(sta_idx).off_periods(i, 2);
        patch([t_start t_end t_end t_start], [y_base y_base y_base+y_height y_base+y_height], ...
            [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        hold on;
    end
    
    % On 구간 (연한 녹색 배경)
    for i = 1:size(sta_data(sta_idx).on_periods, 1)
        t_start = sta_data(sta_idx).on_periods(i, 1);
        t_end = sta_data(sta_idx).on_periods(i, 2);
        patch([t_start t_end t_end t_start], [y_base y_base y_base+y_height y_base+y_height], ...
            [0.8 1 0.8], 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    end
    
    % 버퍼 빈 구간 (빨간 줄)
    for i = 1:size(sta_data(sta_idx).buffer_empty_periods, 1)
        t_start = sta_data(sta_idx).buffer_empty_periods(i, 1);
        t_end = sta_data(sta_idx).buffer_empty_periods(i, 2);
        plot([t_start t_end], [0.5 0.5], 'r-', 'LineWidth', 3);
    end
    
    % 패킷 도착 (파란 점)
    if ~isempty(sta_data(sta_idx).packets)
        plot(sta_data(sta_idx).packets, 0.5*ones(size(sta_data(sta_idx).packets)), ...
            'b.', 'MarkerSize', 8);
    end
    
    hold off;
    
    xlim([0 sim_time]);
    ylim([0 1]);
    ylabel(sprintf('STA %d', sta_idx));
    set(gca, 'YTick', []);
    
    if sta_idx == 1
        title('On/Off 구간 vs 버퍼 빈 구간 (녹색=On, 회색=Off, 빨간선=버퍼빈구간, 파란점=패킷도착)');
    end
    if sta_idx == num_stas
        xlabel('Time (s)');
    end
    
    grid on;
end

%% Figure 2: 버퍼 빈 기간 분포
figure('Name', 'Buffer Empty Duration Distribution', 'Position', [100 100 1000 600]);

% 모든 STA의 버퍼 빈 기간 수집
all_empty_durations = [];
for sta_idx = 1:num_stas
    periods = sta_data(sta_idx).buffer_empty_periods;
    if ~isempty(periods)
        durations = (periods(:,2) - periods(:,1)) * 1000;  % ms 단위
        all_empty_durations = [all_empty_durations; durations];
    end
end

% Off 구간 기간 수집
all_off_durations = [];
for sta_idx = 1:num_stas
    periods = sta_data(sta_idx).off_periods;
    if ~isempty(periods)
        durations = (periods(:,2) - periods(:,1)) * 1000;  % ms 단위
        all_off_durations = [all_off_durations; durations];
    end
end

subplot(2,2,1);
histogram(all_empty_durations, 30, 'FaceColor', [0.9 0.4 0.4]);
xlabel('버퍼 빈 기간 (ms)');
ylabel('빈도');
title('버퍼 빈 기간 분포');
xline(30, 'g--', 'T_{hold}=30ms', 'LineWidth', 2);
xline(50, 'b--', 'T_{hold}=50ms', 'LineWidth', 2);
xline(70, 'm--', 'T_{hold}=70ms', 'LineWidth', 2);
grid on;

subplot(2,2,2);
histogram(all_off_durations, 30, 'FaceColor', [0.5 0.5 0.5]);
xlabel('Off 구간 기간 (ms)');
ylabel('빈도');
title('Off 구간 분포');
xline(mu_off*1000, 'r--', sprintf('μ_{off}=%.0fms', mu_off*1000), 'LineWidth', 2);
grid on;

subplot(2,2,3);
% CDF 직접 계산
x_empty = sort(all_empty_durations);
f_empty = (1:length(x_empty))' / length(x_empty);
x_off = sort(all_off_durations);
f_off = (1:length(x_off))' / length(x_off);
plot(x_empty, f_empty, 'r-', 'LineWidth', 2); hold on;
plot(x_off, f_off, 'k--', 'LineWidth', 2);
xline(30, 'g:', 'LineWidth', 1.5);
xline(50, 'b:', 'LineWidth', 1.5);
xline(70, 'm:', 'LineWidth', 1.5);
hold off;
xlabel('기간 (ms)');
ylabel('CDF');
title('버퍼 빈 기간 vs Off 구간 CDF');
legend({'버퍼 빈 기간', 'Off 구간', 'T=30', 'T=50', 'T=70'}, 'Location', 'southeast');
xlim([0 200]);
grid on;

subplot(2,2,4);
% T_hold 별 커버리지
tholds = [10 20 30 40 50 60 70 80 90 100];
coverage = zeros(size(tholds));
for i = 1:length(tholds)
    coverage(i) = sum(all_empty_durations <= tholds(i)) / length(all_empty_durations) * 100;
end
plot(tholds, coverage, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
xlabel('T_{hold} (ms)');
ylabel('커버리지 (%)');
title('T_{hold} 값에 따른 버퍼 빈 기간 커버리지');
grid on;
ylim([0 100]);

%% 통계 출력
fprintf('\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('                    통계 요약\n');
fprintf('═══════════════════════════════════════════════════════════════\n');
fprintf('\n[버퍼 빈 기간]\n');
fprintf('  샘플 수: %d\n', length(all_empty_durations));
fprintf('  평균: %.1f ms\n', mean(all_empty_durations));
fprintf('  중위값: %.1f ms\n', median(all_empty_durations));
fprintf('  표준편차: %.1f ms\n', std(all_empty_durations));
sorted_empty = sort(all_empty_durations);
n = length(sorted_empty);
fprintf('  P10: %.1f ms\n', sorted_empty(round(0.1*n)));
fprintf('  P50: %.1f ms\n', sorted_empty(round(0.5*n)));
fprintf('  P90: %.1f ms\n', sorted_empty(round(0.9*n)));

fprintf('\n[Off 구간]\n');
fprintf('  샘플 수: %d\n', length(all_off_durations));
fprintf('  평균: %.1f ms\n', mean(all_off_durations));
fprintf('  중위값: %.1f ms\n', median(all_off_durations));
fprintf('  설정 μ_off: %.1f ms\n', mu_off*1000);

fprintf('\n[T_hold 커버리지]\n');
fprintf('  T_hold=30ms: %.1f%%\n', sum(all_empty_durations <= 30) / length(all_empty_durations) * 100);
fprintf('  T_hold=50ms: %.1f%%\n', sum(all_empty_durations <= 50) / length(all_empty_durations) * 100);
fprintf('  T_hold=70ms: %.1f%%\n', sum(all_empty_durations <= 70) / length(all_empty_durations) * 100);

%% 저장
output_dir = 'results/thold_analysis';
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
saveas(figure(1), fullfile(output_dir, 'timeline.png'));
saveas(figure(2), fullfile(output_dir, 'distribution.png'));
fprintf('\n[저장 완료] %s/\n', output_dir);