module optimal_cache (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] c,
    input wire [4:0] a,
    input wire [4:0] obj_addr,
    input wire [3:0] obj_data,
    input wire obj_write,
    output reg [7:0] miss_count,
    output reg done
);
    // Parameters
    localparam MAX_CACHE = 4;
    localparam MAX_SEQ = 16;

    // State encoding
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] INIT  = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] MISS  = 3'd3;
    localparam [2:0] ADD   = 3'd4;
    localparam [2:0] EVICT = 3'd5;
    localparam [2:0] NEXT  = 3'd6;
    localparam [2:0] DONE  = 3'd7;

    // Sequence memory and Cache
    reg [3:0] seq [0:MAX_SEQ-1];
    reg [3:0] cache [0:MAX_CACHE-1];
    reg valid [0:MAX_CACHE-1];
    
    // Registers
    reg [4:0] current_index;
    reg [2:0] occupied;
    reg [2:0] state;
    reg [2:0] next_state;

    // Combinational signals
    reg hit;
    reg [2:0] hit_slot;
    reg has_empty;
    reg [2:0] empty_slot;
    reg [4:0] next_use [0:MAX_CACHE-1];
    reg [2:0] evict_slot;
    reg [4:0] max_next_use;

    integer i, j;

    // Write sequence memory
    always @(posedge clk) begin
        if (obj_write) begin
            seq[obj_addr] <= obj_data;
        end
    end

    // Hit detection
    always @(*) begin
        hit = 1'b0;
        hit_slot = 3'd0;
        for (i = 0; i < MAX_CACHE; i = i + 1) begin
            if (i < c && valid[i] && cache[i] == seq[current_index]) begin
                hit = 1'b1;
                hit_slot = i[2:0];
            end
        end
    end

    // Empty slot detection
    always @(*) begin
        has_empty = 1'b0;
        empty_slot = 3'd0;
        for (i = 0; i < MAX_CACHE; i = i + 1) begin
            if (i < c && !valid[i] && !has_empty) begin
                has_empty = 1'b1;
                empty_slot = i[2:0];
            end
        end
    end

    // Next use computation
    always @(*) begin
        for (i = 0; i < MAX_CACHE; i = i + 1) begin
            next_use[i] = a;
            if (i < c && valid[i]) begin
                for (j = current_index + 1; j < MAX_SEQ; j = j + 1) begin
                    if (j < a && seq[j] == cache[i] && next_use[i] == a) begin
                        next_use[i] = j[4:0];
                    end
                end
            end
        end
    end

    // Evict slot selection
    always @(*) begin
        max_next_use = 5'd0;
        evict_slot = 3'd0;
        for (i = 0; i < MAX_CACHE; i = i + 1) begin
            if (i < c && valid[i] && next_use[i] > max_next_use) begin
                max_next_use = next_use[i];
                evict_slot = i[2:0];
            end
        end
    end

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 5'd0;
            occupied <= 3'd0;
            miss_count <= 8'd0;
            done <= 1'b0;
            for (i = 0; i < MAX_CACHE; i = i + 1) begin
                cache[i] <= 4'd0;
                valid[i] <= 1'b0;
            end
        end else begin
            state <= next_state;

            case (state)
                INIT: begin
                    occupied <= 3'd0;
                    miss_count <= 8'd0;
                    current_index <= 5'd0;
                    for (i = 0; i < MAX_CACHE; i = i + 1) begin
                        valid[i] <= 1'b0;
                        cache[i] <= 4'd0;
                    end
                end

                ADD: begin
                    cache[empty_slot] <= seq[current_index];
                    valid[empty_slot] <= 1'b1;
                    occupied <= occupied + 3'd1;
                end

                EVICT: begin
                    cache[evict_slot] <= seq[current_index];
                    valid[evict_slot] <= 1'b1;
                end

                NEXT: begin
                    current_index <= current_index + 5'd1;
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state; // default stay

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = CHECK;
            end

            CHECK: begin
                if (hit) begin
                    next_state = NEXT;
                end else begin
                    next_state = MISS;
                end
            end

            MISS: begin
                if (has_empty) begin
                    next_state = ADD;
                end else begin
                    next_state = EVICT;
                end
            end

            ADD: begin
                next_state = NEXT;
            end

            EVICT: begin
                next_state = NEXT;
            end

            NEXT: begin
                if (current_index + 5'd1 < a) begin
                    next_state = CHECK;
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Increment miss_count on ADD or EVICT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            miss_count <= 8'd0;
        end else begin
            if (state == ADD || state == EVICT) begin
                miss_count <= miss_count + 8'd1;
            end
        end
    end

endmodule