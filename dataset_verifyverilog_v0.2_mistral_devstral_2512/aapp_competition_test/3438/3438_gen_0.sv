module introspective_cache (
    input clk,
    input rst_n,
    input start,
    input [3:0] access_i,
    input valid_i,
    output reg [2:0] read_count,
    output reg done
);

    parameter CACHE_SIZE = 8;
    parameter LOOKAHEAD_DEPTH = 16;
    parameter OBJECT_BITS = 4;

    typedef struct {
        logic valid;
        logic [OBJECT_BITS-1:0] object_id;
    } cache_slot_t;

    cache_slot_t cache [CACHE_SIZE];
    logic [OBJECT_BITS-1:0] lookahead_buffer [LOOKAHEAD_DEPTH];
    logic [$clog2(LOOKAHEAD_DEPTH):0] lookahead_head;
    logic [$clog2(LOOKAHEAD_DEPTH):0] lookahead_tail;
    logic [$clog2(LOOKAHEAD_DEPTH):0] lookahead_count;

    typedef enum logic [2:0] {
        IDLE,
        FILL_WINDOW,
        PROCESS_ACCESS,
        UPDATE_CACHE,
        LOOKAHEAD_SHIFT,
        DONE
    } state_t;

    state_t current_state, next_state;

    logic [OBJECT_BITS-1:0] current_access;
    logic access_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            read_count <= 0;
            done <= 0;
            lookahead_head <= 0;
            lookahead_tail <= 0;
            lookahead_count <= 0;
            for (int i = 0; i < CACHE_SIZE; i++) begin
                cache[i].valid <= 0;
                cache[i].object_id <= 0;
            end
            for (int i = 0; i < LOOKAHEAD_DEPTH; i++) begin
                lookahead_buffer[i] <= 0;
            end
            current_access <= 0;
            access_valid <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == UPDATE_CACHE && !access_valid) begin
                read_count <= read_count + 1;
            end
            if (next_state == DONE) begin
                done <= 1;
            end
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = FILL_WINDOW;
                end
            end
            FILL_WINDOW: begin
                if (valid_i && lookahead_count < LOOKAHEAD_DEPTH) begin
                    lookahead_buffer[lookahead_tail] = access_i;
                    lookahead_tail = (lookahead_tail + 1) % LOOKAHEAD_DEPTH;
                    lookahead_count = lookahead_count + 1;
                end else if (lookahead_count == LOOKAHEAD_DEPTH) begin
                    next_state = PROCESS_ACCESS;
                    current_access = lookahead_buffer[lookahead_head];
                    access_valid = 1;
                end
            end
            PROCESS_ACCESS: begin
                logic hit = 0;
                for (int i = 0; i < CACHE_SIZE; i++) begin
                    if (cache[i].valid && cache[i].object_id == current_access) begin
                        hit = 1;
                    end
                end
                if (!hit) begin
                    next_state = UPDATE_CACHE;
                end else begin
                    next_state = LOOKAHEAD_SHIFT;
                end
            end
            UPDATE_CACHE: begin
                logic empty_slot_found = 0;
                for (int i = 0; i < CACHE_SIZE; i++) begin
                    if (!cache[i].valid) begin
                        cache[i].valid = 1;
                        cache[i].object_id = current_access;
                        empty_slot_found = 1;
                        break;
                    end
                end
                if (!empty_slot_found) begin
                    logic [OBJECT_BITS-1:0] evict_candidate;
                    logic [$clog2(LOOKAHEAD_DEPTH+1):0] farthest_index = 0;
                    for (int i = 0; i < CACHE_SIZE; i++) begin
                        logic [$clog2(LOOKAHEAD_DEPTH+1):0] next_use = 0;
                        for (int j = 0; j < lookahead_count; j++) begin
                            if (lookahead_buffer[(lookahead_head + j) % LOOKAHEAD_DEPTH] == cache[i].object_id) begin
                                next_use = j + 1;
                                break;
                            end
                        end
                        if (next_use > farthest_index) begin
                            farthest_index = next_use;
                            evict_candidate = cache[i].object_id;
                        end
                    end
                    for (int i = 0; i < CACHE_SIZE; i++) begin
                        if (cache[i].object_id == evict_candidate) begin
                            cache[i].object_id = current_access;
                            break;
                        end
                    end
                end
                next_state = LOOKAHEAD_SHIFT;
            end
            LOOKAHEAD_SHIFT: begin
                lookahead_head = (lookahead_head + 1) % LOOKAHEAD_DEPTH;
                lookahead_count = lookahead_count - 1;
                if (valid_i && lookahead_count < LOOKAHEAD_DEPTH) begin
                    lookahead_buffer[lookahead_tail] = access_i;
                    lookahead_tail = (lookahead_tail + 1) % LOOKAHEAD_DEPTH;
                    lookahead_count = lookahead_count + 1;
                end
                if (lookahead_count == 0) begin
                    next_state = DONE;
                end else begin
                    current_access = lookahead_buffer[lookahead_head];
                    access_valid = 1;
                    next_state = PROCESS_ACCESS;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    done = 0;
                end
            end
        endcase
    end

endmodule