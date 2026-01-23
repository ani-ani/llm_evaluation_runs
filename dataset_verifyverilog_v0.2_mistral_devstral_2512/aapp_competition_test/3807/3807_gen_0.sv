module limak_tower (
    input clk,
    input rst_n,
    input start,
    input [49:0] m_in,
    output reg [5:0] blocks_out,
    output reg [49:0] volume_out,
    output reg done
);

    // Stack definitions
    localparam STACK_DEPTH = 20;
    localparam VAL_WIDTH = 50;
    localparam A_WIDTH = 17;
    localparam STAGE_WIDTH = 2;
    localparam ACCUM_WIDTH = 50;
    localparam BLOCKS_WIDTH = 6;

    // Stack entry structure
    typedef struct {
        logic [VAL_WIDTH-1:0] val;
        logic [A_WIDTH-1:0] a;
        logic [STAGE_WIDTH-1:0] stage;
        logic [ACCUM_WIDTH-1:0] accum_vol;
        logic [BLOCKS_WIDTH-1:0] result_blocks;
        logic [VAL_WIDTH-1:0] result_vol;
    } stack_entry_t;

    stack_entry_t stack [0:STACK_DEPTH-1];
    logic [3:0] sp = 0;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        FIND_ROOT,
        CALCULATE_SUB1,
        CALCULATE_SUB2,
        COMPARE,
        UPDATE_STACK,
        DONE
    } state_t;
    state_t state = IDLE;

    // Temporary storage
    logic [VAL_WIDTH-1:0] current_val;
    logic [A_WIDTH-1:0] current_a;
    logic [STAGE_WIDTH-1:0] current_stage;
    logic [ACCUM_WIDTH-1:0] current_accum;
    logic [BLOCKS_WIDTH-1:0] temp_blocks1, temp_blocks2;
    logic [VAL_WIDTH-1:0] temp_vol1, temp_vol2;

    // Root finding variables
    logic [A_WIDTH-1:0] root_low, root_high, root_mid;
    logic [VAL_WIDTH-1:0] cube_mid;

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sp <= 0;
            blocks_out <= 0;
            volume_out <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Push initial problem onto stack
                        stack[0].val = m_in;
                        stack[0].a = 0;
                        stack[0].stage = 0;
                        stack[0].accum_vol = 0;
                        stack[0].result_blocks = 0;
                        stack[0].result_vol = 0;
                        sp <= 1;
                        state <= FIND_ROOT;
                    end
                end
                FIND_ROOT: begin
                    if (sp > 0) begin
                        current_val = stack[sp-1].val;
                        current_stage = stack[sp-1].stage;
                        current_accum = stack[sp-1].accum_vol;
                        
                        if (current_val < 8) begin
                            // Base case: all blocks of size 1
                            stack[sp-1].result_blocks = current_val;
                            stack[sp-1].result_vol = current_val;
                            state <= UPDATE_STACK;
                        end else begin
                            // Initialize binary search for cube root
                            root_low = 1;
                            root_high = 17'h10000; // 10^5
                            state <= FIND_ROOT;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                CALCULATE_SUB1: begin
                    // Process first subproblem: val - a^3
                    if (sp < STACK_DEPTH) begin
                        stack[sp].val = current_val - (current_a * current_a * current_a);
                        stack[sp].a = 0;
                        stack[sp].stage = 0;
                        stack[sp].accum_vol = current_accum + (current_a * current_a * current_a);
                        stack[sp].result_blocks = 0;
                        stack[sp].result_vol = 0;
                        sp <= sp + 1;
                        // Update current entry to wait for result
                        stack[sp-2].stage = 1;
                        state <= FIND_ROOT;
                    end else begin
                        state <= DONE;
                    end
                end
                CALCULATE_SUB2: begin
                    // Process second subproblem: a^3 - 1 - (a-1)^3
                    if (sp < STACK_DEPTH) begin
                        stack[sp].val = (current_a * current_a * current_a) - 1 - ((current_a - 1) * (current_a - 1) * (current_a - 1));
                        stack[sp].a = 0;
                        stack[sp].stage = 0;
                        stack[sp].accum_vol = current_accum + ((current_a - 1) * (current_a - 1) * (current_a - 1));
                        stack[sp].result_blocks = 0;
                        stack[sp].result_vol = 0;
                        sp <= sp + 1;
                        // Store first result temporarily
                        temp_blocks1 = stack[sp-2].result_blocks;
                        temp_vol1 = stack[sp-2].result_vol;
                        state <= FIND_ROOT;
                    end else begin
                        state <= DONE;
                    end
                end
                COMPARE: begin
                    // Compare two results
                    temp_blocks2 = stack[sp-1].result_blocks;
                    temp_vol2 = stack[sp-1].result_vol;
                    
                    if (temp_blocks1 > temp_blocks2 || (temp_blocks1 == temp_blocks2 && temp_vol1 > temp_vol2)) begin
                        stack[sp-2].result_blocks = temp_blocks1;
                        stack[sp-2].result_vol = temp_vol1;
                    end else begin
                        stack[sp-2].result_blocks = temp_blocks2;
                        stack[sp-2].result_vol = temp_vol2;
                    end
                    sp <= sp - 1;
                    state <= UPDATE_STACK;
                end
                UPDATE_STACK: begin
                    if (sp > 1) begin
                        // Propagate result up the stack
                        stack[sp-2].result_blocks = stack[sp-1].result_blocks;
                        stack[sp-2].result_vol = stack[sp-1].result_vol;
                        sp <= sp - 1;
                        state <= FIND_ROOT;
                    end else if (sp == 1) begin
                        // Final result
                        blocks_out <= stack[0].result_blocks;
                        volume_out <= stack[0].result_vol;
                        done <= 1;
                        state <= DONE;
                    end else begin
                        state <= IDLE;
                    end
                end
                DONE: begin
                    if (!start) begin
                        done <= 0;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // Binary search for cube root
    always @(posedge clk) begin
        if (state == FIND_ROOT && root_low <= root_high) begin
            root_mid = (root_low + root_high) / 2;
            cube_mid = root_mid * root_mid * root_mid;
            
            if (cube_mid <= current_val && (root_mid + 1) * (root_mid + 1) * (root_mid + 1) > current_val) begin
                current_a = root_mid;
                stack[sp-1].a = current_a;
                
                if (current_stage == 0) begin
                    state <= CALCULATE_SUB1;
                end else if (current_stage == 1) begin
                    state <= CALCULATE_SUB2;
                end else if (current_stage == 2) begin
                    state <= COMPARE;
                end
            end else if (cube_mid < current_val) begin
                root_low = root_mid + 1;
            end else begin
                root_high = root_mid - 1;
            end
        end
    end

endmodule