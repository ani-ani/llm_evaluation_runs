module SublistChecker (
    input clk,
    input rst_n,
    input start,
    input [2:0] main_len,
    input [2:0] sub_len,
    input [7:0] main_arr [0:7],
    input [7:0] sub_arr [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_LEN  = 3'd1;
    localparam [2:0] SETUP_LOOP = 3'd2;
    localparam [2:0] COMPARE    = 3'd3;
    localparam [2:0] FOUND      = 3'd4;
    localparam [2:0] NOT_FOUND  = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] main_pos;
    reg [2:0] sub_pos;
    reg [2:0] max_main_pos;
    reg match_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            main_pos <= 3'd0;
            sub_pos <= 3'd0;
            max_main_pos <= 3'd0;
            match_found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_LEN;
                    end
                end

                CHECK_LEN: begin
                    if (sub_len > main_len) begin
                        state <= NOT_FOUND;
                    end else begin
                        max_main_pos <= main_len - sub_len;
                        main_pos <= 3'd0;
                        match_found <= 1'b0;
                        state <= SETUP_LOOP;
                    end
                end

                SETUP_LOOP: begin
                    if (main_pos <= max_main_pos) begin
                        sub_pos <= 3'd0;
                        state <= COMPARE;
                    end else begin
                        state <= (match_found) ? FOUND : NOT_FOUND;
                    end
                end

                COMPARE: begin
                    if (sub_pos < sub_len) begin
                        if (main_arr[main_pos + sub_pos] == sub_arr[sub_pos]) begin
                            sub_pos <= sub_pos + 3'd1;
                        end else begin
                            main_pos <= main_pos + 3'd1;
                            state <= SETUP_LOOP;
                        end
                    end else begin
                        match_found <= 1'b1;
                        state <= FOUND;
                    end
                end

                FOUND: begin
                    result <= 1'b1;
                    state <= FINISH;
                end

                NOT_FOUND: begin
                    result <= 1'b0;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule