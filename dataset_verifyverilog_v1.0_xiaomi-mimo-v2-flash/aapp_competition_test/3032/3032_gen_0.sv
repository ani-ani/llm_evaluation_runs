module min_instruction_count (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] token,
    input wire [3:0] b,
    input wire [3:0] s,
    input wire token_valid,
    output reg [15:0] min_cycles,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] READ_PROGRAM  = 3'd1;
    localparam [2:0] COMPUTE_START = 3'd2;
    localparam [2:0] COMPUTE_PERM  = 3'd3;
    localparam [2:0] SIMULATE      = 3'd4;
    localparam [2:0] UPDATE_MIN    = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] prog [0:999]; // Program storage (max 1000 tokens)
    reg [9:0] prog_len;      // Actual program length
    reg [9:0] rd_ptr;        // Read pointer during input
    reg [9:0] sim_ptr;       // Simulation pointer
    reg [3:0] current_b;     // Current bank for simulation
    reg [3:0] current_s;     // Current slot for simulation
    reg [15:0] cycle_count;  // Current simulation cycle count
    reg [15:0] temp_min;     // Temporary minimum
    reg [3:0] var_bank [0:12]; // Variable to bank mapping (V1-V13)
    reg [3:0] next_var_bank; // Next variable to assign in permutation
    reg [3:0] var_idx;       // Variable index for simulation
    reg [3:0] token_type;    // Token type: 0=E, 1=V1..13
    reg [3:0] token_idx;     // Variable index from token
    reg [2:0] bsr_state;     // BSR state: 0-12, or 15 for undefined (-1)
    reg [15:0] total_cycles; // Total cycles for current mapping
    reg [7:0] cycle_counter; // Cycle limit counter
    localparam [7:0] MAX_CYCLES = 8'd130;

    // Token encoding constants
    localparam [3:0] TOK_E  = 4'd0;
    localparam [3:0] TOK_V  = 4'd1;
    localparam [3:0] TOK_R  = 4'd2;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            prog_len <= 10'd0;
            rd_ptr <= 10'd0;
            sim_ptr <= 10'd0;
            current_b <= 4'd0;
            current_s <= 4'd0;
            cycle_count <= 16'd0;
            temp_min <= 16'hFFFF;
            min_cycles <= 16'd0;
            done <= 1'b0;
            cycle_counter <= 8'd0;
            bsr_state <= 4'd15; // Undefined (-1)
            total_cycles <= 16'd0;
            next_var_bank <= 4'd0;
            var_idx <= 4'd0;
            token_type <= 4'd0;
            token_idx <= 4'd0;
            // Initialize var_bank
            for (int i = 0; i < 13; i = i + 1) begin
                var_bank[i] <= 4'd0;
            end
            // Initialize prog
            for (int i = 0; i < 1000; i = i + 1) begin
                prog[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        prog_len <= 10'd0;
                        rd_ptr <= 10'd0;
                    end
                    done <= 1'b0;
                end
                READ_PROGRAM: begin
                    if (token_valid) begin
                        prog[rd_ptr] <= token;
                        rd_ptr <= rd_ptr + 10'd1;
                    end
                end
                COMPUTE_START: begin
                    sim_ptr <= 10'd0;
                    cycle_counter <= 8'd0;
                    next_var_bank <= 4'd0;
                    temp_min <= 16'hFFFF;
                    // Reset var_bank
                    for (int i = 0; i < 13; i = i + 1) begin
                        var_bank[i] <= 4'd0;
                    end
                end
                COMPUTE_PERM: begin
                    // Generate next permutation
                    if (next_var_bank < 13) begin
                        // Assign current variable
                        if (var_bank[next_var_bank] < (b - 1)) begin
                            var_bank[next_var_bank] <= var_bank[next_var_bank] + 4'd1;
                        end else begin
                            var_bank[next_var_bank] <= 4'd0;
                            next_var_bank <= next_var_bank + 4'd1;
                        end
                    end
                end
                SIMULATE: begin
                    if (sim_ptr < prog_len) begin
                        token_type <= prog[sim_ptr][15:12];
                        token_idx <= prog[sim_ptr][3:0];
                        sim_ptr <= sim_ptr + 10'd1;
                        if (prog[sim_ptr][15:12] == TOK_E) begin
                            // E instruction
                            total_cycles <= total_cycles + 16'd1;
                        end else if (prog[sim_ptr][15:12] == TOK_V) begin
                            // Variable access
                            if (token_idx < 13) begin
                                if (var_bank[token_idx] == 4'd0) begin
                                    // Bank 0: use direct slot
                                    total_cycles <= total_cycles + 16'd1;
                                end else begin
                                    // Other bank: check BSR
                                    if (bsr_state != var_bank[token_idx]) begin
                                        total_cycles <= total_cycles + 16'd2; // BSR + access
                                        bsr_state <= var_bank[token_idx];
                                    end else begin
                                        total_cycles <= total_cycles + 16'd1; // Access only
                                    end
                                end
                            end
                        end else if (prog[sim_ptr][15:12] == TOK_R) begin
                            // R instruction: reset BSR
                            bsr_state <= 4'd15;
                            total_cycles <= total_cycles + 16'd1;
                        end
                    end
                    cycle_counter <= cycle_counter + 8'd1;
                end
                UPDATE_MIN: begin
                    if (total_cycles < temp_min) begin
                        temp_min <= total_cycles;
                    end
                    total_cycles <= 16'd0;
                    bsr_state <= 4'd15;
                end
                FINISH: begin
                    min_cycles <= temp_min;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = READ_PROGRAM;
            end
            READ_PROGRAM: begin
                if (!token_valid && rd_ptr > 0) begin
                    prog_len = rd_ptr;
                    next_state = COMPUTE_START;
                end
            end
            COMPUTE_START: begin
                if (b > 0 && s > 0) next_state = COMPUTE_PERM;
                else next_state = FINISH;
            end
            COMPUTE_PERM: begin
                if (next_var_bank >= 13) begin
                    next_state = SIMULATE;
                end
            end
            SIMULATE: begin
                if (sim_ptr >= prog_len || cycle_counter >= MAX_CYCLES) begin
                    next_state = UPDATE_MIN;
                end
            end
            UPDATE_MIN: begin
                // Check if all permutations done
                if (var_bank[0] >= (b - 1) && var_bank[1] >= (b - 1) && 
                    var_bank[2] >= (b - 1) && var_bank[3] >= (b - 1) && 
                    var_bank[4] >= (b - 1) && var_bank[5] >= (b - 1) &&
                    var_bank[6] >= (b - 1) && var_bank[7] >= (b - 1) &&
                    var_bank[8] >= (b - 1) && var_bank[9] >= (b - 1) &&
                    var_bank[10] >= (b - 1) && var_bank[11] >= (b - 1) &&
                    var_bank[12] >= (b - 1)) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE_PERM;
                end
            end
            FINISH: begin
                if (!done) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule