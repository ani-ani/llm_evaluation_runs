module greedy_tower(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] m,
    output reg [4:0] blocks,
    output reg [19:0] volume,
    output reg done
);

    // Parameters
    localparam [4:0] MAX_DEPTH = 5'd18;
    localparam [4:0] DATA_WIDTH = 5'd20;
    localparam [5:0] STACK_WIDTH = 6'd36;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_CUBEROOT = 3'd1;
    localparam [2:0] PUSH_STACK = 3'd2;
    localparam [2:0] PROCESS_STACK = 3'd3;
    localparam [2:0] UPDATE_BEST = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Registers
    reg [2:0] state;
    reg [4:0] current_blocks;
    reg [19:0] current_volume;
    reg [4:0] current_a;
    reg [19:0] current_m;
    reg [4:0] stack_ptr;
    reg [4:0] best_blocks;
    reg [19:0] best_volume;
    reg [4:0] cube_root;
    reg [5:0] cycle_count;
    reg [5:0] max_cycles;

    // Stack memory
    reg [STACK_WIDTH-1:0] stack [0:17];

    // Cube root computation registers
    reg [6:0] cube_low;
    reg [6:0] cube_high;
    reg [6:0] cube_mid;
    reg [35:0] cube_mid_cubed;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_blocks <= 5'd0;
            current_volume <= 20'd0;
            current_a <= 5'd0;
            current_m <= 20'd0;
            stack_ptr <= 5'd0;
            best_blocks <= 5'd0;
            best_volume <= 20'd0;
            cube_root <= 5'd0;
            cycle_count <= 6'd0;
            max_cycles <= 6'd1000;
            blocks <= 5'd0;
            volume <= 20'd0;
            done <= 1'b0;

            // Initialize stack
            integer i;
            for (i = 0; i < 18; i = i + 1) begin
                stack[i] <= 36'd0;
            end

            cube_low <= 7'd0;
            cube_high <= 7'd100;
            cube_mid <= 7'd0;
            cube_mid_cubed <= 36'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        state <= COMPUTE_CUBEROOT;
                        current_m <= m;
                        cube_low <= 7'd0;
                        cube_high <= 7'd100;
                    end
                end

                COMPUTE_CUBEROOT: begin
                    if (cube_low > cube_high) begin
                        cube_root <= cube_high;
                        state <= PUSH_STACK;
                    end else begin
                        cube_mid <= (cube_low + cube_high) >> 1;
                        cube_mid_cubed <= cube_mid * cube_mid * cube_mid;

                        if (cube_mid_cubed > current_m) begin
                            cube_high <= cube_mid - 7'd1;
                        end else begin
                            cube_low <= cube_mid + 7'd1;
                        end
                    end
                end

                PUSH_STACK: begin
                    if (stack_ptr < MAX_DEPTH) begin
                        // Push current state to stack
                        stack[stack_ptr] <= {current_blocks, current_volume, current_a, current_m};
                        stack_ptr <= stack_ptr + 5'd1;

                        // Process path A: use cube_root
                        current_a <= cube_root;
                        current_blocks <= current_blocks + 5'd1;
                        current_volume <= current_volume + (cube_root * cube_root * cube_root);
                        current_m <= current_m - (cube_root * cube_root * cube_root);

                        if (current_m == 20'd0) begin
                            state <= UPDATE_BEST;
                        end else begin
                            state <= COMPUTE_CUBEROOT;
                        end
                    end else begin
                        state <= UPDATE_BEST;
                    end
                end

                PROCESS_STACK: begin
                    if (stack_ptr > 5'd0) begin
                        stack_ptr <= stack_ptr - 5'd1;
                        {current_blocks, current_volume, current_a, current_m} <= stack[stack_ptr];

                        // Process path B: use cube_root - 1
                        current_a <= cube_root - 5'd1;
                        current_m <= current_m - ((3 * cube_root * cube_root) - (3 * cube_root) + 5'd1);
                        current_blocks <= current_blocks + 5'd1;
                        current_volume <= current_volume + ((cube_root - 5'd1) * (cube_root - 5'd1) * (cube_root - 5'd1));

                        if (current_m == 20'd0) begin
                            state <= UPDATE_BEST;
                        end else begin
                            state <= COMPUTE_CUBEROOT;
                        end
                    end else begin
                        state <= UPDATE_BEST;
                    end
                end

                UPDATE_BEST: begin
                    if (current_blocks > best_blocks || 
                        (current_blocks == best_blocks && current_volume > best_volume)) begin
                        best_blocks <= current_blocks;
                        best_volume <= current_volume;
                    end

                    if (stack_ptr > 5'd0) begin
                        state <= PROCESS_STACK;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    blocks <= best_blocks;
                    volume <= best_volume;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Cycle counter for safety
            if (cycle_count < max_cycles) begin
                cycle_count <= cycle_count + 6'd1;
            end else begin
                state <= IDLE;
            end
        end
    end

endmodule