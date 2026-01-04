classdef MetricsCollector < handle
% METRICSCOLLECTOR: 성능 메트릭 수집기
%
% 시뮬레이션 중 다양한 성능 지표 수집 및 분석

    properties
        cfg                     % 설정
        
        %% TF별 누적 카운터
        total_tf_count          % 총 TF 횟수 (워밍업 제외)
        
        % UORA (RA-RU)
        ra_success_count        % RA-RU 성공 횟수
        ra_collision_count      % RA-RU 충돌에 참여한 STA 수 (누적)
        ra_collision_slots      % RA-RU 충돌 발생 슬롯 수
        ra_idle_count           % RA-RU 유휴 횟수
        
        % SA-RU
        sa_tx_count             % SA-RU 전송 횟수
        sa_idle_count           % SA-RU 유휴 횟수
        sa_allocation_count     % SA-RU 할당 횟수 (phantom 포함)
        
        % BSR
        explicit_bsr_count      % Explicit BSR 횟수
        implicit_bsr_count      % Implicit BSR 횟수
        
        % 처리율
        total_tx_bytes          % 총 전송 바이트
        
        %% 패킷 레벨 메트릭
        delays                  % 지연 시간 배열 (슬롯 단위)
        delay_idx               % 현재 인덱스
        
        %% STA별 메트릭
        per_sta_success         % STA별 성공 횟수
        per_sta_collision       % STA별 충돌 횟수
        per_sta_bytes           % STA별 전송 바이트
        
        %% T_hold 추가 지표
        thold_wasted_slots      % T_hold 만료로 낭비된 슬롯
        thold_phantom_count     % T_hold로 인한 Phantom (빈 SA 할당) 횟수
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = MetricsCollector(cfg)
            obj.cfg = cfg;
            obj.reset();
        end
        
        %% ═══════════════════════════════════════════════════
        %  리셋
        %  ═══════════════════════════════════════════════════
        
        function reset(obj)
            obj.total_tf_count = 0;
            
            obj.ra_success_count = 0;
            obj.ra_collision_count = 0;
            obj.ra_collision_slots = 0;
            obj.ra_idle_count = 0;
            
            obj.sa_tx_count = 0;
            obj.sa_idle_count = 0;
            obj.sa_allocation_count = 0;
            
            obj.explicit_bsr_count = 0;
            obj.implicit_bsr_count = 0;
            
            obj.total_tx_bytes = 0;
            
            obj.delays = zeros(obj.cfg.max_packets, 1);
            obj.delay_idx = 0;
            
            obj.per_sta_success = zeros(obj.cfg.num_stas, 1);
            obj.per_sta_collision = zeros(obj.cfg.num_stas, 1);
            obj.per_sta_bytes = zeros(obj.cfg.num_stas, 1);
            
            obj.thold_wasted_slots = 0;
            obj.thold_phantom_count = 0;
        end
        
        %% ═══════════════════════════════════════════════════
        %  TF별 수집
        %  ═══════════════════════════════════════════════════
        
        function collect(obj, slot, success, collided, idle, sa_assignments, stas, ~, collision_slots)
            obj.total_tf_count = obj.total_tf_count + 1;
            
            % RA-RU 통계
            ra_success = sum(strcmp({success.tx_type}, 'ra'));
            sa_success = sum(strcmp({success.tx_type}, 'sa'));
            
            obj.ra_success_count = obj.ra_success_count + ra_success;
            obj.ra_collision_count = obj.ra_collision_count + length(collided);
            obj.ra_collision_slots = obj.ra_collision_slots + collision_slots;
            obj.ra_idle_count = obj.ra_idle_count + idle.ra;
            
            % SA-RU 통계
            obj.sa_tx_count = obj.sa_tx_count + sa_success;
            obj.sa_idle_count = obj.sa_idle_count + idle.sa;
            obj.sa_allocation_count = obj.sa_allocation_count + length(sa_assignments);
            
            % 성공한 전송 처리
            for i = 1:length(success)
                sta_idx = success(i).sta_idx;
                obj.per_sta_success(sta_idx) = obj.per_sta_success(sta_idx) + 1;
                obj.per_sta_bytes(sta_idx) = obj.per_sta_bytes(sta_idx) + obj.cfg.mpdu_size;
                obj.total_tx_bytes = obj.total_tx_bytes + obj.cfg.mpdu_size;
            end
            
            % 충돌한 전송 처리
            for i = 1:length(collided)
                sta_idx = collided(i);
                obj.per_sta_collision(sta_idx) = obj.per_sta_collision(sta_idx) + 1;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  BSR 기록
        %  ═══════════════════════════════════════════════════
        
        function record_explicit_bsr(obj)
            obj.explicit_bsr_count = obj.explicit_bsr_count + 1;
        end
        
        function record_implicit_bsr(obj)
            obj.implicit_bsr_count = obj.implicit_bsr_count + 1;
        end
        
        function record_phantom(obj, count)
            % T_hold로 인한 Phantom (빈 SA 할당) 기록
            obj.thold_phantom_count = obj.thold_phantom_count + count;
            % Phantom은 SA idle로도 카운트
            obj.sa_idle_count = obj.sa_idle_count + count;
        end
        
        %% ═══════════════════════════════════════════════════
        %  지연 기록
        %  ═══════════════════════════════════════════════════
        
        function record_delay(obj, delay_slots)
            if obj.delay_idx < obj.cfg.max_packets
                obj.delay_idx = obj.delay_idx + 1;
                obj.delays(obj.delay_idx) = delay_slots;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  T_hold 낭비 슬롯 기록
        %  ═══════════════════════════════════════════════════
        
        function record_thold_wasted(obj, wasted_slots)
            obj.thold_wasted_slots = obj.thold_wasted_slots + wasted_slots;
        end
        
        %% ═══════════════════════════════════════════════════
        %  최종 결과 계산
        %  ═══════════════════════════════════════════════════
        
        function results = finalize(obj, stas)
            results = struct();
            
            %% ═══════════════════════════════════════════════════
            %  패킷 통계
            %  ═══════════════════════════════════════════════════
            
            total_generated = sum([stas.num_packets]);
            total_completed = sum([stas.completed_packets]);
            
            results.packets.generated = total_generated;
            results.packets.completed = total_completed;
            if total_generated > 0
                results.packets.completion_rate = total_completed / total_generated;
            else
                results.packets.completion_rate = 0;
            end
            
            %% ═══════════════════════════════════════════════════
            %  지연 통계 (분해 포함)
            %  ═══════════════════════════════════════════════════
            
            % 완료된 패킷에서 지연 데이터 수집
            all_total_delay = [];
            all_initial_wait = [];
            all_uora_contention = [];
            all_sa_wait = [];
            
            % 패킷 분류별 지연 배열
            % [1] UORA 스킵 여부
            uora_skipped_delays = [];    % UORA 안 거친 패킷
            uora_used_delays = [];       % UORA 거친 패킷
            
            % [2] UORA 스킵 이유별
            thold_hit_delays = [];       % T_hold hit으로 스킵
            sa_queue_delays = [];        % SA queue로 스킵
            
            % [3] 전송 타입별
            ra_packet_delays = [];       % RA-RU로 전송
            sa_packet_delays = [];       % SA-RU로 전송
            
            for i = 1:length(stas)
                for j = 1:stas(i).num_packets
                    pkt = stas(i).packets(j);
                    if pkt.completed
                        all_total_delay(end+1) = pkt.delay_slots;
                        all_initial_wait(end+1) = pkt.initial_wait_slots;
                        all_uora_contention(end+1) = pkt.uora_contention_slots;
                        all_sa_wait(end+1) = pkt.sa_wait_slots;
                        
                        % [1] UORA 스킵 여부
                        if pkt.uora_skipped
                            uora_skipped_delays(end+1) = pkt.delay_slots;
                        else
                            uora_used_delays(end+1) = pkt.delay_slots;
                        end
                        
                        % [2] UORA 스킵 이유별
                        if strcmp(pkt.skip_reason, 'thold_hit')
                            thold_hit_delays(end+1) = pkt.delay_slots;
                        elseif strcmp(pkt.skip_reason, 'sa_queue')
                            sa_queue_delays(end+1) = pkt.delay_slots;
                        end
                        
                        % [3] 전송 타입별
                        if strcmp(pkt.tx_type, 'ra')
                            ra_packet_delays(end+1) = pkt.delay_slots;
                        else
                            sa_packet_delays(end+1) = pkt.delay_slots;
                        end
                    end
                end
            end
            
            % 슬롯 → ms 변환
            slot_to_ms = obj.cfg.slot_duration * 1000;
            
            % Total Delay 통계
            if ~isempty(all_total_delay)
                delay_ms = all_total_delay * slot_to_ms;
                results.delay.mean_ms = mean(delay_ms);
                results.delay.std_ms = std(delay_ms);
                results.delay.min_ms = min(delay_ms);
                results.delay.p10_ms = prctile(delay_ms, 10);
                results.delay.p50_ms = prctile(delay_ms, 50);
                results.delay.p90_ms = prctile(delay_ms, 90);
                results.delay.p99_ms = prctile(delay_ms, 99);
                results.delay.max_ms = max(delay_ms);
                results.delay.all_ms = delay_ms;  % CDF 그래프용 전체 배열
            else
                results.delay.mean_ms = 0;
                results.delay.std_ms = 0;
                results.delay.min_ms = 0;
                results.delay.p10_ms = 0;
                results.delay.p50_ms = 0;
                results.delay.p90_ms = 0;
                results.delay.p99_ms = 0;
                results.delay.max_ms = 0;
                results.delay.all_ms = [];
            end
            
            % Initial Wait 통계
            if ~isempty(all_initial_wait)
                init_ms = all_initial_wait * slot_to_ms;
                results.delay_decomp.initial_wait.mean_ms = mean(init_ms);
                results.delay_decomp.initial_wait.std_ms = std(init_ms);
                results.delay_decomp.initial_wait.p90_ms = prctile(init_ms, 90);
            else
                results.delay_decomp.initial_wait.mean_ms = 0;
                results.delay_decomp.initial_wait.std_ms = 0;
                results.delay_decomp.initial_wait.p90_ms = 0;
            end
            
            % UORA Contention 통계
            if ~isempty(all_uora_contention)
                uora_ms = all_uora_contention * slot_to_ms;
                results.delay_decomp.uora_contention.mean_ms = mean(uora_ms);
                results.delay_decomp.uora_contention.std_ms = std(uora_ms);
                results.delay_decomp.uora_contention.p90_ms = prctile(uora_ms, 90);
                % UORA를 거친 패킷만 (0 제외)
                uora_nonzero = uora_ms(uora_ms > 0);
                if ~isempty(uora_nonzero)
                    results.delay_decomp.uora_contention.mean_when_used_ms = mean(uora_nonzero);
                else
                    results.delay_decomp.uora_contention.mean_when_used_ms = 0;
                end
            else
                results.delay_decomp.uora_contention.mean_ms = 0;
                results.delay_decomp.uora_contention.std_ms = 0;
                results.delay_decomp.uora_contention.p90_ms = 0;
                results.delay_decomp.uora_contention.mean_when_used_ms = 0;
            end
            
            % SA Scheduling Wait 통계
            if ~isempty(all_sa_wait)
                sa_ms = all_sa_wait * slot_to_ms;
                results.delay_decomp.sa_wait.mean_ms = mean(sa_ms);
                results.delay_decomp.sa_wait.std_ms = std(sa_ms);
                results.delay_decomp.sa_wait.p90_ms = prctile(sa_ms, 90);
            else
                results.delay_decomp.sa_wait.mean_ms = 0;
                results.delay_decomp.sa_wait.std_ms = 0;
                results.delay_decomp.sa_wait.p90_ms = 0;
            end
            
            %% ═══════════════════════════════════════════════════
            %  패킷 분류별 지연 통계
            %  ═══════════════════════════════════════════════════
            
            % [1] UORA 스킵 vs UORA 사용
            if ~isempty(uora_skipped_delays)
                skipped_ms = uora_skipped_delays * slot_to_ms;
                results.pkt_class.uora_skipped.count = length(uora_skipped_delays);
                results.pkt_class.uora_skipped.ratio = length(uora_skipped_delays) / total_completed;
                results.pkt_class.uora_skipped.mean_ms = mean(skipped_ms);
                results.pkt_class.uora_skipped.std_ms = std(skipped_ms);
                results.pkt_class.uora_skipped.min_ms = min(skipped_ms);
                results.pkt_class.uora_skipped.p10_ms = prctile(skipped_ms, 10);
                results.pkt_class.uora_skipped.p50_ms = prctile(skipped_ms, 50);
                results.pkt_class.uora_skipped.p90_ms = prctile(skipped_ms, 90);
                results.pkt_class.uora_skipped.p99_ms = prctile(skipped_ms, 99);
                results.pkt_class.uora_skipped.max_ms = max(skipped_ms);
            else
                results.pkt_class.uora_skipped.count = 0;
                results.pkt_class.uora_skipped.ratio = 0;
                results.pkt_class.uora_skipped.mean_ms = 0;
                results.pkt_class.uora_skipped.std_ms = 0;
                results.pkt_class.uora_skipped.min_ms = 0;
                results.pkt_class.uora_skipped.p10_ms = 0;
                results.pkt_class.uora_skipped.p50_ms = 0;
                results.pkt_class.uora_skipped.p90_ms = 0;
                results.pkt_class.uora_skipped.p99_ms = 0;
                results.pkt_class.uora_skipped.max_ms = 0;
            end
            
            if ~isempty(uora_used_delays)
                used_ms = uora_used_delays * slot_to_ms;
                results.pkt_class.uora_used.count = length(uora_used_delays);
                results.pkt_class.uora_used.ratio = length(uora_used_delays) / total_completed;
                results.pkt_class.uora_used.mean_ms = mean(used_ms);
                results.pkt_class.uora_used.std_ms = std(used_ms);
                results.pkt_class.uora_used.min_ms = min(used_ms);
                results.pkt_class.uora_used.p10_ms = prctile(used_ms, 10);
                results.pkt_class.uora_used.p50_ms = prctile(used_ms, 50);
                results.pkt_class.uora_used.p90_ms = prctile(used_ms, 90);
                results.pkt_class.uora_used.p99_ms = prctile(used_ms, 99);
                results.pkt_class.uora_used.max_ms = max(used_ms);
            else
                results.pkt_class.uora_used.count = 0;
                results.pkt_class.uora_used.ratio = 0;
                results.pkt_class.uora_used.mean_ms = 0;
                results.pkt_class.uora_used.std_ms = 0;
                results.pkt_class.uora_used.min_ms = 0;
                results.pkt_class.uora_used.p10_ms = 0;
                results.pkt_class.uora_used.p50_ms = 0;
                results.pkt_class.uora_used.p90_ms = 0;
                results.pkt_class.uora_used.p99_ms = 0;
                results.pkt_class.uora_used.max_ms = 0;
            end
            
            % [2] UORA 스킵 세부: T_hold Hit vs SA Queue
            if ~isempty(thold_hit_delays)
                hit_ms = thold_hit_delays * slot_to_ms;
                results.pkt_class.thold_hit.count = length(thold_hit_delays);
                results.pkt_class.thold_hit.ratio = length(thold_hit_delays) / total_completed;
                results.pkt_class.thold_hit.mean_ms = mean(hit_ms);
                results.pkt_class.thold_hit.std_ms = std(hit_ms);
                results.pkt_class.thold_hit.min_ms = min(hit_ms);
                results.pkt_class.thold_hit.p10_ms = prctile(hit_ms, 10);
                results.pkt_class.thold_hit.p50_ms = prctile(hit_ms, 50);
                results.pkt_class.thold_hit.p90_ms = prctile(hit_ms, 90);
                results.pkt_class.thold_hit.p99_ms = prctile(hit_ms, 99);
                results.pkt_class.thold_hit.max_ms = max(hit_ms);
            else
                results.pkt_class.thold_hit.count = 0;
                results.pkt_class.thold_hit.ratio = 0;
                results.pkt_class.thold_hit.mean_ms = 0;
                results.pkt_class.thold_hit.std_ms = 0;
                results.pkt_class.thold_hit.min_ms = 0;
                results.pkt_class.thold_hit.p10_ms = 0;
                results.pkt_class.thold_hit.p50_ms = 0;
                results.pkt_class.thold_hit.p90_ms = 0;
                results.pkt_class.thold_hit.p99_ms = 0;
                results.pkt_class.thold_hit.max_ms = 0;
            end
            
            if ~isempty(sa_queue_delays)
                queue_ms = sa_queue_delays * slot_to_ms;
                results.pkt_class.sa_queue.count = length(sa_queue_delays);
                results.pkt_class.sa_queue.ratio = length(sa_queue_delays) / total_completed;
                results.pkt_class.sa_queue.mean_ms = mean(queue_ms);
                results.pkt_class.sa_queue.std_ms = std(queue_ms);
                results.pkt_class.sa_queue.min_ms = min(queue_ms);
                results.pkt_class.sa_queue.p10_ms = prctile(queue_ms, 10);
                results.pkt_class.sa_queue.p50_ms = prctile(queue_ms, 50);
                results.pkt_class.sa_queue.p90_ms = prctile(queue_ms, 90);
                results.pkt_class.sa_queue.p99_ms = prctile(queue_ms, 99);
                results.pkt_class.sa_queue.max_ms = max(queue_ms);
            else
                results.pkt_class.sa_queue.count = 0;
                results.pkt_class.sa_queue.ratio = 0;
                results.pkt_class.sa_queue.mean_ms = 0;
                results.pkt_class.sa_queue.std_ms = 0;
                results.pkt_class.sa_queue.min_ms = 0;
                results.pkt_class.sa_queue.p10_ms = 0;
                results.pkt_class.sa_queue.p50_ms = 0;
                results.pkt_class.sa_queue.p90_ms = 0;
                results.pkt_class.sa_queue.p99_ms = 0;
                results.pkt_class.sa_queue.max_ms = 0;
            end
            
            % [3] 전송 타입별: RA vs SA
            if ~isempty(ra_packet_delays)
                ra_ms = ra_packet_delays * slot_to_ms;
                results.pkt_class.ra_tx.count = length(ra_packet_delays);
                results.pkt_class.ra_tx.ratio = length(ra_packet_delays) / total_completed;
                results.pkt_class.ra_tx.mean_ms = mean(ra_ms);
                results.pkt_class.ra_tx.std_ms = std(ra_ms);
                results.pkt_class.ra_tx.min_ms = min(ra_ms);
                results.pkt_class.ra_tx.p10_ms = prctile(ra_ms, 10);
                results.pkt_class.ra_tx.p50_ms = prctile(ra_ms, 50);
                results.pkt_class.ra_tx.p90_ms = prctile(ra_ms, 90);
                results.pkt_class.ra_tx.p99_ms = prctile(ra_ms, 99);
                results.pkt_class.ra_tx.max_ms = max(ra_ms);
            else
                results.pkt_class.ra_tx.count = 0;
                results.pkt_class.ra_tx.ratio = 0;
                results.pkt_class.ra_tx.mean_ms = 0;
                results.pkt_class.ra_tx.std_ms = 0;
                results.pkt_class.ra_tx.min_ms = 0;
                results.pkt_class.ra_tx.p10_ms = 0;
                results.pkt_class.ra_tx.p50_ms = 0;
                results.pkt_class.ra_tx.p90_ms = 0;
                results.pkt_class.ra_tx.p99_ms = 0;
                results.pkt_class.ra_tx.max_ms = 0;
            end
            
            if ~isempty(sa_packet_delays)
                sa_tx_ms = sa_packet_delays * slot_to_ms;
                results.pkt_class.sa_tx.count = length(sa_packet_delays);
                results.pkt_class.sa_tx.ratio = length(sa_packet_delays) / total_completed;
                results.pkt_class.sa_tx.mean_ms = mean(sa_tx_ms);
                results.pkt_class.sa_tx.std_ms = std(sa_tx_ms);
                results.pkt_class.sa_tx.min_ms = min(sa_tx_ms);
                results.pkt_class.sa_tx.p10_ms = prctile(sa_tx_ms, 10);
                results.pkt_class.sa_tx.p50_ms = prctile(sa_tx_ms, 50);
                results.pkt_class.sa_tx.p90_ms = prctile(sa_tx_ms, 90);
                results.pkt_class.sa_tx.p99_ms = prctile(sa_tx_ms, 99);
                results.pkt_class.sa_tx.max_ms = max(sa_tx_ms);
            else
                results.pkt_class.sa_tx.count = 0;
                results.pkt_class.sa_tx.ratio = 0;
                results.pkt_class.sa_tx.mean_ms = 0;
                results.pkt_class.sa_tx.std_ms = 0;
                results.pkt_class.sa_tx.min_ms = 0;
                results.pkt_class.sa_tx.p10_ms = 0;
                results.pkt_class.sa_tx.p50_ms = 0;
                results.pkt_class.sa_tx.p90_ms = 0;
                results.pkt_class.sa_tx.p99_ms = 0;
                results.pkt_class.sa_tx.max_ms = 0;
            end
            
            % 하위 호환성: delay_decomp에도 기존 필드 유지
            results.delay_decomp.thold_hit.count = results.pkt_class.thold_hit.count;
            results.delay_decomp.thold_hit.ratio = results.pkt_class.thold_hit.ratio;
            results.delay_decomp.thold_hit.mean_ms = results.pkt_class.thold_hit.mean_ms;
            
            results.delay_decomp.non_thold.count = results.pkt_class.uora_used.count + results.pkt_class.sa_queue.count;
            results.delay_decomp.non_thold.ratio = results.pkt_class.uora_used.ratio + results.pkt_class.sa_queue.ratio;
            if results.delay_decomp.non_thold.count > 0
                % uora_used + sa_queue의 가중 평균
                results.delay_decomp.non_thold.mean_ms = ...
                    (results.pkt_class.uora_used.mean_ms * results.pkt_class.uora_used.count + ...
                     results.pkt_class.sa_queue.mean_ms * results.pkt_class.sa_queue.count) / ...
                    results.delay_decomp.non_thold.count;
            else
                results.delay_decomp.non_thold.mean_ms = 0;
            end
            
            results.delay_decomp.ra_packets.count = results.pkt_class.ra_tx.count;
            results.delay_decomp.ra_packets.mean_ms = results.pkt_class.ra_tx.mean_ms;
            
            results.delay_decomp.sa_packets.count = results.pkt_class.sa_tx.count;
            results.delay_decomp.sa_packets.mean_ms = results.pkt_class.sa_tx.mean_ms;
            
            %% ═══════════════════════════════════════════════════
            %  처리율 및 채널 효율 통계
            %  ═══════════════════════════════════════════════════
            
            % effective_time = TF 횟수 × TF 주기(슬롯) × 슬롯 길이
            effective_time = obj.total_tf_count * obj.cfg.frame_exchange_slots * obj.cfg.slot_duration;
            if effective_time > 0
                results.throughput.total_mbps = (obj.total_tx_bytes * 8) / effective_time / 1e6;
            else
                results.throughput.total_mbps = 0;
            end
            
            % RA-RU Utilization (성공 / 전체 RA-RU 기회)
            total_ra_ru_opportunities = obj.total_tf_count * obj.cfg.num_ru_ra;
            if total_ra_ru_opportunities > 0
                results.throughput.ra_utilization = obj.ra_success_count / total_ra_ru_opportunities;
            else
                results.throughput.ra_utilization = 0;
            end
            
            % SA-RU Utilization (실제 전송 / 할당된 SA-RU)
            if obj.sa_allocation_count > 0
                results.throughput.sa_utilization = obj.sa_tx_count / obj.sa_allocation_count;
            else
                results.throughput.sa_utilization = 1;  % 할당이 없으면 낭비도 없음
            end
            
            % SA Phantom Rate (빈 할당 비율)
            if obj.sa_allocation_count > 0
                results.throughput.sa_phantom_rate = 1 - (obj.sa_tx_count / obj.sa_allocation_count);
                results.throughput.sa_phantom_count = obj.sa_allocation_count - obj.sa_tx_count;
            else
                results.throughput.sa_phantom_rate = 0;
                results.throughput.sa_phantom_count = 0;
            end
            
            % 전체 채널 이용률
            total_ru_opportunities = obj.total_tf_count * obj.cfg.num_ru_total;
            total_success = obj.ra_success_count + obj.sa_tx_count;
            if total_ru_opportunities > 0
                results.throughput.channel_utilization = total_success / total_ru_opportunities;
            else
                results.throughput.channel_utilization = 0;
            end
            
            %% ═══════════════════════════════════════════════════
            %  UORA/충돌 통계
            %  ═══════════════════════════════════════════════════
            
            total_ra_attempts = obj.ra_success_count + obj.ra_collision_count;
            % RA-RU 슬롯 수: success + collision_slots + idle
            total_ra_slots = obj.ra_success_count + obj.ra_collision_slots + obj.ra_idle_count;
            
            % RA-RU 슬롯 기준 비율 (시스템 관점)
            if total_ra_slots > 0
                results.uora.success_rate = obj.ra_success_count / total_ra_slots;
                results.uora.collision_slot_rate = obj.ra_collision_slots / total_ra_slots;
                results.uora.idle_rate = obj.ra_idle_count / total_ra_slots;
            else
                results.uora.success_rate = 0;
                results.uora.collision_slot_rate = 0;
                results.uora.idle_rate = 0;
            end
            
            % 충돌률 (STA 관점): 시도 중 충돌 비율
            % collision_rate = collision_stas / (success + collision_stas)
            if total_ra_attempts > 0
                results.uora.collision_rate = obj.ra_collision_count / total_ra_attempts;
            else
                results.uora.collision_rate = 0;
            end
            
            % 충돌당 평균 참여 STA 수
            if obj.ra_collision_slots > 0
                results.uora.avg_collision_size = obj.ra_collision_count / obj.ra_collision_slots;
            else
                results.uora.avg_collision_size = 0;
            end
            
            % 패킷당 충돌 횟수 (시스템 전체)
            if total_completed > 0
                results.uora.collisions_per_packet = obj.ra_collision_count / total_completed;
            else
                results.uora.collisions_per_packet = 0;
            end
            
            results.uora.total_attempts = total_ra_attempts;
            results.uora.total_success = obj.ra_success_count;
            results.uora.total_collision = obj.ra_collision_count;
            results.uora.total_collision_slots = obj.ra_collision_slots;
            results.uora.total_idle = obj.ra_idle_count;
            results.uora.total_ra_slots = total_ra_slots;
            
            %% ═══════════════════════════════════════════════════
            %  BSR 통계
            %  ═══════════════════════════════════════════════════
            
            results.bsr.explicit_count = obj.explicit_bsr_count;
            results.bsr.implicit_count = obj.implicit_bsr_count;
            
            total_bsr = obj.explicit_bsr_count + obj.implicit_bsr_count;
            if total_bsr > 0
                results.bsr.explicit_ratio = obj.explicit_bsr_count / total_bsr;
            else
                results.bsr.explicit_ratio = 0;
            end
            
            %% ═══════════════════════════════════════════════════
            %  T_hold 통계 (Simulator/THoldManager에서 채워짐)
            %  ═══════════════════════════════════════════════════
            
            results.thold.activations = 0;
            results.thold.hits = 0;
            results.thold.expirations = 0;
            results.thold.hit_rate = 0;
            results.thold.wasted_slots = obj.thold_wasted_slots;
            results.thold.wasted_ms = obj.thold_wasted_slots * obj.cfg.slot_duration * 1000;
            results.thold.phantom_count = obj.thold_phantom_count;
            
            %% ═══════════════════════════════════════════════════
            %  TF 통계
            %  ═══════════════════════════════════════════════════
            
            results.tf.count = obj.total_tf_count;
            results.tf.period_slots = obj.cfg.frame_exchange_slots;
            results.tf.period_ms = obj.cfg.frame_exchange_slots * obj.cfg.slot_duration * 1000;
            
            %% ═══════════════════════════════════════════════════
            %  공정성 (Jain's Fairness Index & CoV)
            %  ═══════════════════════════════════════════════════
            
            if obj.cfg.num_stas > 0 && effective_time > 0
                throughputs = obj.per_sta_bytes * 8 / effective_time / 1e6;  % Mbps
                sum_th = sum(throughputs);
                sum_th_sq = sum(throughputs.^2);
                
                if sum_th_sq > 0
                    results.fairness.jain_index = sum_th^2 / (obj.cfg.num_stas * sum_th_sq);
                else
                    results.fairness.jain_index = 1;
                end
                
                % Coefficient of Variation
                if sum_th > 0
                    results.fairness.cov = std(throughputs) / mean(throughputs);
                else
                    results.fairness.cov = 0;
                end
                
                % Min/Max Throughput Ratio (NEW)
                if max(throughputs) > 0
                    results.fairness.min_max_ratio = min(throughputs) / max(throughputs);
                else
                    results.fairness.min_max_ratio = 1;
                end
            else
                results.fairness.jain_index = 1;
                results.fairness.cov = 0;
                results.fairness.min_max_ratio = 1;
            end
            
            %% ═══════════════════════════════════════════════════
            %  Per-STA 통계
            %  ═══════════════════════════════════════════════════
            
            if obj.cfg.collect_per_sta && effective_time > 0
                results.per_sta.success = obj.per_sta_success;
                results.per_sta.collision = obj.per_sta_collision;
                results.per_sta.bytes = obj.per_sta_bytes;
                results.per_sta.throughput_mbps = obj.per_sta_bytes * 8 / effective_time / 1e6;
            end
        end
    end
end