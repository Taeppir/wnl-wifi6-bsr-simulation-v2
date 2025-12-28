classdef Simulator < handle
% SIMULATOR: 메인 시뮬레이터 클래스
%
% Time-slot 기반 IEEE 802.11ax UORA 시뮬레이터
%
% 사용법:
%   sim = Simulator(cfg);
%   results = sim.run();

    properties (SetAccess = private)
        cfg             % 설정 구조체
        
        % 네트워크 엔티티
        ap              % Access Point
        stas            % Stations (배열)
        rus             % Resource Units
        
        % 매니저/프로세서
        traffic         % TrafficGenerator
        uora            % UORAProcessor
        bsr             % BSRManager
        thold           % THoldManager
        collision       % CollisionDetector
        metrics         % MetricsCollector
        
        % 상태
        current_slot    % 현재 슬롯
        is_initialized  % 초기화 여부
    end
    
    methods
        %% ═══════════════════════════════════════════════════
        %  생성자
        %  ═══════════════════════════════════════════════════
        
        function obj = Simulator(cfg)
            obj.cfg = cfg;
            obj.is_initialized = false;
            obj.current_slot = 0;
            
            % 랜덤 시드 설정
            if isfield(cfg, 'seed')
                rng(cfg.seed);
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  초기화
        %  ═══════════════════════════════════════════════════
        
        function initialize(obj)
            if obj.cfg.verbose >= 2
                fprintf('\n[초기화]\n');
            end
            
            % 1. 네트워크 엔티티 생성
            obj.create_entities();
            
            % 2. 매니저/프로세서 생성
            obj.create_managers();
            
            % 3. 트래픽 생성
            obj.generate_traffic();
            
            obj.is_initialized = true;
            
            if obj.cfg.verbose >= 2
                fprintf('  초기화 완료\n');
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  시뮬레이션 실행
        %  ═══════════════════════════════════════════════════
        
        function results = run(obj)
            % 초기화 확인
            if ~obj.is_initialized
                obj.initialize();
            end
            
            % Time-slot 루프 실행
            results = obj.run_slot_loop();
        end
    end
    
    methods (Access = private)
        %% ═══════════════════════════════════════════════════
        %  엔티티 생성
        %  ═══════════════════════════════════════════════════
        
        function create_entities(obj)
            % AP 생성
            obj.ap = AP(obj.cfg);
            
            % STAs 생성
            obj.stas = STA.empty(obj.cfg.num_stas, 0);
            for i = 1:obj.cfg.num_stas
                obj.stas(i) = STA(i, obj.cfg);
            end
            
            % RUs 생성
            obj.rus = RU(obj.cfg);
            
            if obj.cfg.verbose >= 2
                fprintf('  엔티티 생성: AP 1개, STA %d개, RU %d개\n', ...
                    obj.cfg.num_stas, obj.cfg.num_ru_total);
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  매니저/프로세서 생성
        %  ═══════════════════════════════════════════════════
        
        function create_managers(obj)
            % 트래픽 생성기
            obj.traffic = TrafficGenerator(obj.cfg);
            
            % UORA 프로세서
            obj.uora = UORAProcessor(obj.cfg);
            
            % BSR 매니저
            obj.bsr = BSRManager(obj.cfg);
            
            % T_hold 매니저
            obj.thold = THoldManager(obj.cfg);
            
            % 충돌 검출기
            obj.collision = CollisionDetector(obj.cfg);
            
            % 메트릭 수집기
            obj.metrics = MetricsCollector(obj.cfg);
            
            if obj.cfg.verbose >= 2
                fprintf('  매니저 생성 완료\n');
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  트래픽 생성
        %  ═══════════════════════════════════════════════════
        
        function generate_traffic(obj)
            obj.stas = obj.traffic.generate(obj.stas);
            
            if obj.cfg.verbose >= 2
                total_pkts = sum([obj.stas.num_packets]);
                fprintf('  트래픽 생성: 총 %d 패킷\n', total_pkts);
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  Time-Slot 루프 (TF 주기 기반)
        %  ═══════════════════════════════════════════════════
        
        function results = run_slot_loop(obj)
            total_slots = obj.cfg.total_slots;
            warmup_slots = obj.cfg.warmup_slots;
            tf_period = obj.cfg.frame_exchange_slots;  % TF 주기 (슬롯 단위)
            
            % 다음 TF 슬롯 (첫 TF는 슬롯 1에서 시작)
            next_tf_slot = 1;
            num_tfs = 0;  % TF 횟수 카운터
            
            if obj.cfg.verbose >= 1
                fprintf('  총 슬롯: %d, 워밍업: %d, TF 주기: %d 슬롯 (%.2f ms)\n', ...
                    total_slots, warmup_slots, tf_period, tf_period * obj.cfg.slot_duration * 1000);
                progress_interval = ceil(total_slots / 10);
            end
            
            for slot = 1:total_slots
                obj.current_slot = slot;
                is_warmup = (slot <= warmup_slots);
                
                % ═══════════════════════════════════════════════════
                % 매 슬롯마다 처리 (9μs 단위)
                % ═══════════════════════════════════════════════════
                
                % ───────────────────────────────────────────
                % Phase 1: 트래픽 도착 처리
                % ───────────────────────────────────────────
                obj.process_traffic_arrivals(slot);
                
                % ───────────────────────────────────────────
                % Phase 2: T_hold 타이머 만료 체크
                % (패킷 도착 직후 체크 → 같은 슬롯 도착 시 Hit 판정)
                % ───────────────────────────────────────────
                if obj.cfg.thold_enabled
                    obj.thold.check_expiry(obj.stas, obj.ap, slot);
                end
                
                % ═══════════════════════════════════════════════════
                % TF 주기마다 처리 (전송 기회)
                % ═══════════════════════════════════════════════════
                
                if slot == next_tf_slot
                    num_tfs = num_tfs + 1;
                    
                    % ───────────────────────────────────────────
                    % Phase 2.5: 첫 TF 슬롯 기록 (지연 분해용)
                    % ───────────────────────────────────────────
                    obj.record_first_tf(slot);
                    
                    % ───────────────────────────────────────────
                    % Phase 3: SA-RU 스케줄링 (BSR 기반)
                    % ───────────────────────────────────────────
                    sa_assignments = obj.schedule_sa_ru();
                    
                    % ───────────────────────────────────────────
                    % Phase 3.5: T_hold Hit/Phantom 판정
                    % SA 할당받은 T_hold STA의 버퍼 확인
                    % 
                    % Note: 실제로 AP는 TF 끝에 전송 결과로 알게 됨.
                    %       같은 TF 주기 내 일이라 여기서 처리해도 결과 동일.
                    % ───────────────────────────────────────────
                    valid_sa = struct('sta_idx', {}, 'ru_idx', {});
                    phantom_count = 0;
                    hit_count = 0;
                    
                    for i = 1:length(sa_assignments)
                        sta_idx = sa_assignments(i).sta_idx;
                        sta = obj.stas(sta_idx);
                        
                        if sta.queue_size > 0
                            % 실제 전송할 데이터 있음
                            valid_sa(end+1) = sa_assignments(i);
                            
                            % T_hold Hit 판정: T_hold 중에 SA 할당받아서 전송
                            if sta.thold_active
                                hit_count = hit_count + 1;
                                sta.thold_active = false;
                                sta.thold_expiry = 0;
                                obj.ap.end_thold(sta_idx);
                                % mode=1 유지 (SA 전송 후 상태는 process_tx_results에서)
                            end
                        else
                            % Phantom! T_hold 중인데 패킷 없음
                            % → SA-RU 1개가 이번 TF에서 낭비됨
                            phantom_count = phantom_count + 1;
                            
                            % Option B: T_hold 유지, 만료까지 계속 SA 시도
                            % thold_active, thold_expiry, mode 모두 유지
                            % → 다음 TF에서 다시 SA 할당받아 시도
                            % (만료는 check_expiry()에서 처리)
                        end
                        
                        obj.stas(sta_idx) = sta;
                    end
                    
                    % 메트릭에 Hit/Phantom 기록
                    if ~is_warmup
                        obj.metrics.record_phantom(phantom_count);
                    end
                    
                    % T_hold Hit 카운트 (THoldManager에 직접 추가)
                    if obj.cfg.thold_enabled
                        obj.thold.hits = obj.thold.hits + hit_count;
                    end
                    
                    % ───────────────────────────────────────────
                    % Phase 4: RA-RU 접근 (UORA)
                    % ───────────────────────────────────────────
                    ra_attempts = obj.process_uora();
                    
                    % ───────────────────────────────────────────
                    % Phase 5: 충돌 검출 및 전송 결과
                    % ───────────────────────────────────────────
                    [success, collided, idle, collision_slots] = obj.collision.detect( ...
                        obj.stas, obj.rus, ra_attempts, valid_sa);
                    
                    % ───────────────────────────────────────────
                    % Phase 6: 전송 결과 처리
                    % ───────────────────────────────────────────
                    obj.process_tx_results(success, collided, slot);
                    
                    % ───────────────────────────────────────────
                    % Phase 7: 메트릭 수집
                    % ───────────────────────────────────────────
                    if ~is_warmup
                        obj.metrics.collect(slot, success, collided, idle, ...
                            sa_assignments, obj.stas, obj.ap, collision_slots);
                    end
                    
                    % 다음 TF 슬롯 설정
                    next_tf_slot = slot + tf_period;
                end
                
                % 진행 상황 출력
                if obj.cfg.verbose >= 1 && mod(slot, progress_interval) == 0
                    fprintf('  진행: %d%% (%d/%d 슬롯, TF %d회)\n', ...
                        round(slot/total_slots*100), slot, total_slots, num_tfs);
                end
            end
            
            if obj.cfg.verbose >= 1
                fprintf('  완료: 총 %d TF 전송\n', num_tfs);
            end
            
            % 최종 결과 계산
            results = obj.metrics.finalize(obj.stas);
            
            % T_hold 통계 추가
            if obj.cfg.thold_enabled
                thold_stats = obj.thold.get_stats();
                results.thold.activations = thold_stats.activations;
                results.thold.hits = thold_stats.hits;
                results.thold.expirations = thold_stats.expirations;
                results.thold.hit_rate = thold_stats.hit_rate;
                results.thold.wasted_slots = thold_stats.wasted_slots;
                results.thold.wasted_ms = thold_stats.wasted_slots * obj.cfg.slot_duration * 1000;
                results.thold.phantom_count = obj.metrics.thold_phantom_count;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  트래픽 도착 처리
        %  ═══════════════════════════════════════════════════
        
        function process_traffic_arrivals(obj, slot)
            current_time = slot * obj.cfg.slot_duration;
            
            for i = 1:length(obj.stas)
                sta = obj.stas(i);
                
                % 이 슬롯에 도착한 패킷 확인
                while sta.next_packet_idx <= sta.num_packets
                    pkt = sta.packets(sta.next_packet_idx);
                    
                    if pkt.arrival_time <= current_time
                        % 패킷을 큐에 추가
                        sta.queue_size = sta.queue_size + pkt.size;
                        sta.queue_packets = sta.queue_packets + 1;
                        pkt.enqueue_slot = slot;
                        
                        % ═══════════════════════════════════════════
                        % 지연 분해용: 도착 시점 상태 기록
                        % ═══════════════════════════════════════════
                        
                        % T_hold 중에 패킷 도착 처리
                        if obj.cfg.thold_enabled && sta.thold_active
                            obj.thold.handle_new_packet(sta, obj.ap, slot);
                            % T_hold Hit! → SA 모드 유지, UORA 스킵
                            pkt.thold_hit = true;
                            pkt.sa_start_slot = slot;
                            pkt.uora_start_slot = 0;  % UORA 안 거침
                            pkt.uora_end_slot = 0;
                        elseif sta.mode == 1
                            % 이미 SA 모드 (큐에 다른 패킷이 있어서)
                            pkt.sa_start_slot = slot;
                            pkt.uora_start_slot = 0;
                            pkt.uora_end_slot = 0;
                            pkt.thold_hit = false;
                        else
                            % RA 모드 → UORA 경쟁 필요
                            pkt.uora_start_slot = slot;
                            pkt.sa_start_slot = 0;
                            pkt.thold_hit = false;
                        end
                        
                        sta.packets(sta.next_packet_idx) = pkt;
                        sta.next_packet_idx = sta.next_packet_idx + 1;
                    else
                        break;
                    end
                end
                
                obj.stas(i) = sta;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  SA-RU 스케줄링
        %  ═══════════════════════════════════════════════════
        
        function assignments = schedule_sa_ru(obj)
            % SA-RU 스케줄링 우선순위:
            %   1순위: BSR > 0 (라운드로빈, 버퍼 다 비울 때까지)
            %   2순위: T_hold 중 (만료 임박 순) → 남는 SA-RU에만
            
            assignments = struct('sta_idx', {}, 'ru_idx', {});
            num_sa_ru = obj.cfg.num_ru_sa;
            ru_idx_base = obj.cfg.num_ru_ra;  % SA-RU 시작 인덱스
            
            bytes_per_ru = obj.cfg.mpdu_size;  % 2000 bytes
            
            %% Step 1: BSR > 0인 STA 수집 (필요한 RU 수 계산)
            bsr_stas = [];  % struct array: sta_idx, bsr, ru_needed
            for i = 1:length(obj.stas)
                if obj.stas(i).mode == 1  % SA 모드
                    bsr_value = obj.ap.bsr_table(i);
                    if bsr_value > 0
                        ru_needed = ceil(bsr_value / bytes_per_ru);
                        bsr_stas = [bsr_stas; struct('sta_idx', i, 'bsr', bsr_value, 'ru_needed', ru_needed)];
                    end
                end
            end
            
            %% Step 2: 라운드로빈으로 SA-RU 할당 (BSR > 0)
            assigned_count = 0;
            sta_assigned_ru = zeros(length(obj.stas), 1);  % 각 STA가 받은 RU 수
            
            if ~isempty(bsr_stas)
                % 라운드로빈: 모든 STA가 필요한 만큼 받을 때까지
                while assigned_count < num_sa_ru
                    assigned_this_round = false;
                    
                    for k = 1:length(bsr_stas)
                        sta_idx = bsr_stas(k).sta_idx;
                        ru_needed = bsr_stas(k).ru_needed;
                        
                        % 아직 더 필요하면 할당
                        if sta_assigned_ru(sta_idx) < ru_needed && assigned_count < num_sa_ru
                            assigned_count = assigned_count + 1;
                            sta_assigned_ru(sta_idx) = sta_assigned_ru(sta_idx) + 1;
                            
                            assignments(end+1).sta_idx = sta_idx;
                            assignments(end).ru_idx = ru_idx_base + assigned_count;
                            
                            assigned_this_round = true;
                        end
                    end
                    
                    % 이번 라운드에서 아무도 안 받았으면 종료
                    if ~assigned_this_round
                        break;
                    end
                end
            end
            
            %% Step 3: 남은 SA-RU → T_hold 단말 (만료 임박 순)
            remaining_ru = num_sa_ru - assigned_count;
            
            if remaining_ru > 0
                % T_hold 중인 STA 수집 (BSR=0인 것만)
                thold_stas = [];
                for i = 1:length(obj.stas)
                    if obj.stas(i).mode == 1 && obj.stas(i).thold_active
                        bsr_value = obj.ap.bsr_table(i);
                        if bsr_value == 0  % BSR>0은 이미 위에서 처리됨
                            thold_stas = [thold_stas; struct('sta_idx', i, 'expiry', obj.stas(i).thold_expiry)];
                        end
                    end
                end
                
                % 만료 임박 순으로 정렬 (expiry 작은 순)
                if ~isempty(thold_stas)
                    expiries = [thold_stas.expiry];
                    [~, sort_idx] = sort(expiries, 'ascend');
                    thold_stas = thold_stas(sort_idx);
                    
                    % 남은 SA-RU만큼 할당
                    num_thold_assign = min(remaining_ru, length(thold_stas));
                    for k = 1:num_thold_assign
                        sta_idx = thold_stas(k).sta_idx;
                        assigned_count = assigned_count + 1;
                        
                        assignments(end+1).sta_idx = sta_idx;
                        assignments(end).ru_idx = ru_idx_base + assigned_count;
                    end
                end
            end
            
            %% Step 4: assigned_ru 업데이트
            for j = 1:length(assignments)
                obj.stas(assignments(j).sta_idx).assigned_ru = assignments(j).ru_idx;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  UORA 처리
        %  ═══════════════════════════════════════════════════
        
        function attempts = process_uora(obj)
            attempts = struct('sta_idx', {}, 'ru_idx', {});
            
            for i = 1:length(obj.stas)
                sta = obj.stas(i);
                
                % RA 모드이고 큐에 데이터가 있으면 UORA 참여
                if sta.mode == 0 && sta.queue_size > 0
                    % OBO 카운터 감소
                    sta.obo = sta.obo - obj.cfg.num_ru_ra;
                    
                    % OBO <= 0이면 RA-RU 접근 시도
                    if sta.obo <= 0
                        % 랜덤 RU 선택
                        selected_ru = randi(obj.cfg.num_ru_ra);
                        sta.selected_ru = selected_ru;
                        sta.attempting = true;
                        
                        attempts(end+1).sta_idx = i;
                        attempts(end).ru_idx = selected_ru;
                    end
                end
                
                obj.stas(i) = sta;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  전송 결과 처리
        %  ═══════════════════════════════════════════════════
        
        function process_tx_results(obj, success, collided, slot)
            % 성공한 전송 처리
            for i = 1:length(success)
                sta_idx = success(i).sta_idx;
                tx_type = success(i).tx_type;  % 'ra' or 'sa'
                
                sta = obj.stas(sta_idx);
                
                % 패킷 완료 처리 (tx_type 전달)
                [sta, completed_pkt] = obj.complete_packet(sta, slot, tx_type);
                
                % BSR 업데이트
                if strcmp(tx_type, 'ra')
                    % Explicit BSR
                    obj.ap.bsr_table(sta_idx) = sta.queue_size;
                    obj.metrics.record_explicit_bsr();
                    
                    % RA 성공 후 큐에 남은 패킷들의 SA 모드 진입 기록
                    if sta.queue_size > 0
                        sta.mode = 1;  % SA 모드로 전환
                        % 큐에 있는 패킷들의 sa_start_slot 기록
                        for j = 1:sta.num_packets
                            if sta.packets(j).enqueue_slot > 0 && ~sta.packets(j).completed
                                if sta.packets(j).sa_start_slot == 0
                                    sta.packets(j).sa_start_slot = slot;
                                    % UORA 종료 시점도 기록
                                    sta.packets(j).uora_end_slot = slot;
                                end
                            end
                        end
                    else
                        % 버퍼 비어있으면 T_hold 시작
                        if obj.cfg.thold_enabled
                            obj.thold.start_timer(sta, obj.ap, sta_idx, slot);
                        else
                            sta.mode = 0;  % RA 모드 유지
                        end
                    end
                else
                    % Implicit BSR (SA 전송)
                    obj.ap.bsr_table(sta_idx) = sta.queue_size;
                    obj.metrics.record_implicit_bsr();
                    
                    if sta.queue_size == 0
                        if obj.cfg.thold_enabled
                            obj.thold.start_timer(sta, obj.ap, sta_idx, slot);
                        else
                            sta.mode = 0;
                        end
                    end
                end
                
                % OCW 리셋
                sta.ocw = obj.cfg.ocw_min;
                sta.obo = randi([0, sta.ocw]);
                sta.attempting = false;
                sta.selected_ru = 0;
                
                obj.stas(sta_idx) = sta;
            end
            
            % 충돌한 전송 처리 (BEB)
            for i = 1:length(collided)
                sta_idx = collided(i);
                sta = obj.stas(sta_idx);
                
                % OCW 증가 (Binary Exponential Backoff)
                sta.ocw = min(2 * (sta.ocw + 1) - 1, obj.cfg.ocw_max);
                sta.obo = randi([0, sta.ocw]);
                sta.attempting = false;
                sta.selected_ru = 0;
                
                obj.stas(sta_idx) = sta;
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  패킷 완료 처리
        %  ═══════════════════════════════════════════════════
        
        function [sta, pkt] = complete_packet(obj, sta, slot, tx_type)
            % 큐에서 가장 오래된 패킷 완료
            pkt = [];
            
            if sta.queue_packets > 0
                % 완료할 패킷 찾기
                for i = 1:sta.num_packets
                    if sta.packets(i).enqueue_slot > 0 && ~sta.packets(i).completed
                        pkt = sta.packets(i);
                        pkt.completion_slot = slot;
                        pkt.completed = true;
                        pkt.delay_slots = slot - pkt.enqueue_slot;
                        
                        % 전송 타입 기록
                        pkt.tx_type = tx_type;
                        
                        % ═══════════════════════════════════════════
                        % 지연 분해 계산
                        % ═══════════════════════════════════════════
                        
                        % Initial Wait: 패킷 도착 → 첫 TF
                        if pkt.first_tf_slot > 0
                            pkt.initial_wait_slots = pkt.first_tf_slot - pkt.enqueue_slot;
                        else
                            pkt.initial_wait_slots = 0;
                        end
                        
                        % UORA Contention: 첫 TF → UORA 성공 (RA 전송인 경우만)
                        if strcmp(tx_type, 'ra')
                            % RA 전송: UORA 경쟁을 거침
                            pkt.uora_end_slot = slot;
                            if pkt.first_tf_slot > 0
                                pkt.uora_contention_slots = slot - pkt.first_tf_slot;
                            else
                                pkt.uora_contention_slots = slot - pkt.enqueue_slot - pkt.initial_wait_slots;
                            end
                            pkt.sa_wait_slots = 0;  % SA를 거치지 않음
                        else
                            % SA 전송
                            if pkt.uora_start_slot > 0 && pkt.uora_end_slot > 0
                                % UORA를 거쳐서 SA로 온 경우
                                pkt.uora_contention_slots = pkt.uora_end_slot - pkt.first_tf_slot;
                                if pkt.uora_contention_slots < 0
                                    pkt.uora_contention_slots = 0;
                                end
                            else
                                % 처음부터 SA였거나 T_hold hit
                                pkt.uora_contention_slots = 0;
                            end
                            
                            % SA Scheduling Wait: SA 진입 → 전송 완료
                            if pkt.sa_start_slot > 0
                                pkt.sa_wait_slots = slot - pkt.sa_start_slot;
                            else
                                pkt.sa_wait_slots = 0;
                            end
                        end
                        
                        sta.packets(i) = pkt;
                        
                        % 큐 업데이트
                        sta.queue_size = sta.queue_size - pkt.size;
                        sta.queue_packets = sta.queue_packets - 1;
                        sta.completed_packets = sta.completed_packets + 1;
                        
                        break;
                    end
                end
            end
        end
        
        %% ═══════════════════════════════════════════════════
        %  첫 TF 슬롯 기록 (지연 분해용)
        %  ═══════════════════════════════════════════════════
        
        function record_first_tf(obj, slot)
            % 큐에 있는 패킷들 중 first_tf_slot이 0인 것들에 기록
            for i = 1:length(obj.stas)
                sta = obj.stas(i);
                
                for j = 1:sta.num_packets
                    pkt = sta.packets(j);
                    % 큐에 있고 (enqueue_slot > 0), 완료되지 않고, 첫 TF 미기록
                    if pkt.enqueue_slot > 0 && ~pkt.completed && pkt.first_tf_slot == 0
                        pkt.first_tf_slot = slot;
                        sta.packets(j) = pkt;
                    end
                end
                
                obj.stas(i) = sta;
            end
        end
    end
end