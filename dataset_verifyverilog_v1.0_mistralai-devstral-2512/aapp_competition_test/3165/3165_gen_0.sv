module rook_attacker(
    input clk,
    input rst_n,
    input start,
    input [5:0] N,
    input [3:0] K,
    input [3:0] P,
    input [5:0] rook_r,
    input [5:0] rook_c,
    input [5:0] rook_x,
    input [5:0] move_r1,
    input [5:0] move_c1,
    input [5:0] move_r2,
    input [5:0] move_c2,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_ROOK = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] PROCESS_MOVE = 3'd3;
    localparam [2:0] UPDATE_ROW = 3'd4;
    localparam [2:0] UPDATE_COL = 3'd5;
    localparam [2:0] RECOMPUTE = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state, next_state;

    // Counters
    reg [3:0] rook_counter;
    reg [3:0] move_counter;
    reg [5:0] row_counter;
    reg [5:0] col_counter;
    reg [5:0] compute_counter;

    // RAMs for row and column XOR sums
    reg [5:0] row_xor [0:63];
    reg [5:0] col_xor [0:63];

    // Intermediate results
    reg [5:0] Zr, Zc;
    reg [15:0] temp_result;
    reg [15:0] N_scaled;
    reg [15:0] Zr_scaled, Zc_scaled;
    reg [15:0] product1, product2;

    // Move data storage
    reg [5:0] stored_r1, stored_c1, stored_r2, stored_c2;

    // Ready signal control
    reg ready_internal;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rook_counter <= 4'd0;
            move_counter <= 4'd0;
            row_counter <= 6'd0;
            col_counter <= 6'd0;
            compute_counter <= 6'd0;
            Zr <= 6'd0;
            Zc <= 6'd0;
            temp_result <= 16'd0;
            N_scaled <= 16'd0;
            Zr_scaled <= 16'd0;
            Zc_scaled <= 16'd0;
            product1 <= 16'd0;
            product2 <= 16'd0;
            stored_r1 <= 6'd0;
            stored_c1 <= 6'd0;
            stored_r2 <= 6'd0;
            stored_c2 <= 6'd0;
            result <= 16'd0;
            done <= 1'b0;
            ready_internal <= 1'b1;
            
            // Initialize RAMs
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                row_xor[i] <= 6'd0;
                col_xor[i] <= 6'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_ROOK;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD_ROOK: begin
                if (rook_counter == K - 1) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = LOAD_ROOK;
                end
            end
            
            COMPUTE: begin
                if (compute_counter == 6'd63) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            DONE_STATE: begin
                if (move_counter == P) begin
                    next_state = IDLE;
                end else begin
                    next_state = PROCESS_MOVE;
                end
            end
            
            PROCESS_MOVE: begin
                next_state = UPDATE_ROW;
            end
            
            UPDATE_ROW: begin
                next_state = UPDATE_COL;
            end
            
            UPDATE_COL: begin
                next_state = RECOMPUTE;
            end
            
            RECOMPUTE: begin
                if (compute_counter == 6'd63) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = RECOMPUTE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Ready signal
    always @(*) begin
        case (state)
            IDLE: ready_internal = 1'b1;
            LOAD_ROOK: ready_internal = 1'b1;
            PROCESS_MOVE: ready_internal = 1'b1;
            default: ready_internal = 1'b0;
        endcase
    end
    assign ready = ready_internal;

    // Rook loading
    always @(posedge clk) begin
        if (state == LOAD_ROOK && ready_internal) begin
            row_xor[rook_r] <= row_xor[rook_r] ^ rook_x;
            col_xor[rook_c] <= col_xor[rook_c] ^ rook_x;
            rook_counter <= rook_counter + 1'b1;
        end
    end

    // Move processing
    always @(posedge clk) begin
        if (state == PROCESS_MOVE && ready_internal) begin
            stored_r1 <= move_r1;
            stored_c1 <= move_c1;
            stored_r2 <= move_r2;
            stored_c2 <= move_c2;
            move_counter <= move_counter + 1'b1;
        end
    end

    // Row update
    always @(posedge clk) begin
        if (state == UPDATE_ROW) begin
            row_xor[stored_r1] <= row_xor[stored_r1] ^ row_xor[stored_r1]; // Placeholder for actual power
            row_xor[stored_r2] <= row_xor[stored_r2] ^ row_xor[stored_r1]; // Placeholder for actual power
        end
    end

    // Column update
    always @(posedge clk) begin
        if (state == UPDATE_COL) begin
            col_xor[stored_c1] <= col_xor[stored_c1] ^ col_xor[stored_c1]; // Placeholder for actual power
            col_xor[stored_c2] <= col_xor[stored_c2] ^ col_xor[stored_c1]; // Placeholder for actual power
        end
    end

    // Compute Zr and Zc
    always @(posedge clk) begin
        if (state == COMPUTE || state == RECOMPUTE) begin
            if (row_counter < N) begin
                if (row_xor[row_counter] == 6'd0) begin
                    Zr <= Zr + 1'b1;
                end
                row_counter <= row_counter + 1'b1;
            end else if (col_counter < N) begin
                if (col_xor[col_counter] == 6'd0) begin
                    Zc <= Zc + 1'b1;
                end
                col_counter <= col_counter + 1'b1;
            end else begin
                compute_counter <= compute_counter + 1'b1;
            end
        end
    end

    // Compute result
    always @(posedge clk) begin
        if (compute_counter == 6'd63) begin
            N_scaled <= N;
            Zr_scaled <= Zr;
            Zc_scaled <= Zc;
            
            // Compute N * (Zr + Zc)
            product1 <= N_scaled * (Zr_scaled + Zc_scaled);
            
            // Compute 2 * Zr * Zc
            product2 <= 2'd2 * (Zr_scaled * Zc_scaled);
            
            // Final result
            temp_result <= product1 - product2;
            result <= temp_result;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Reset counters after computation
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            row_counter <= 6'd0;
            col_counter <= 6'd0;
            compute_counter <= 6'd0;
            Zr <= 6'd0;
            Zc <= 6'd0;
        end
    end

endmodule