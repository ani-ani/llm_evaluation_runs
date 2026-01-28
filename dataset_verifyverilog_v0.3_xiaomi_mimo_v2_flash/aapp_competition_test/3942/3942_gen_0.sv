module TreasureSolver (
    input clk,
    input rst_n,
    input start,
    input [1:0] char_arr [0:15],
    input [4:0] length,
    output reg [7:0] assign_arr [0:7],
    output reg [3:0] num_hashes,
    output reg done,
    output reg fail
);

    localparam [3:0] MAX_LEN = 4'd16;
    localparam [2:0] MAX_HASHES = 3'd8;
    localparam [2:0] CHAR_WIDTH = 2'd2;

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] COUNT_PAREN = 4'd1;
    localparam [3:0] COUNT_HASH = 4'd2;
    localparam [3:0] CALC_LAST  = 4'd3;
    localparam [3:0] VERIFY_PRE = 4'd4;
    localparam [3:0] SIMULATE   = 4'd5;
    localparam [3:0] VERIFY_POST = 4'd6;
    localparam [3:0] FILL_ARRAY = 4'd7;
    localparam [3:0] SET_DONE   = 4'd8;
    localparam [3:0] SET_FAIL   = 4'd9;

    reg [3:0] state, next_state;
    reg [4:0] idx;
    reg [5:0] open_count;
    reg [5:0] close_count;
    reg [3:0] hash_count;
    reg [3:0] last_hash_pos;
    reg [7:0] last_assign;
    reg [4:0] balance;
    reg [2:0] hash_idx;
    reg [7:0] assign_val;
    reg [2:0] fill_idx;
    reg [7:0] temp_assign [0:7];
    reg [3:0] temp_num_hashes;
    reg verification_failed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            fail <= 1'b0;
            idx <= 5'd0;
            open_count <= 6'd0;
            close_count <= 6'd0;
            hash_count <= 4'd0;
            last_hash_pos <= 4'd0;
            last_assign <= 8'd0;
            balance <= 5'd0;
            hash_idx <= 3'd0;
            assign_val <= 8'd0;
            fill_idx <= 3'd0;
            temp_num_hashes <= 4'd0;
            verification_failed <= 1'b0;
            num_hashes <= 4'd0;
            // Initialize assign_arr
            assign_arr[0] <= 8'd0;
            assign_arr[1] <= 8'd0;
            assign_arr[2] <= 8'd0;
            assign_arr[3] <= 8'd0;
            assign_arr[4] <= 8'd0;
            assign_arr[5] <= 8'd0;
            assign_arr[6] <= 8'd0;
            assign_arr[7] <= 8'd0;
            // Initialize temp_assign
            temp_assign[0] <= 8'd0;
            temp_assign[1] <= 8'd0;
            temp_assign[2] <= 8'd0;
            temp_assign[3] <= 8'd0;
            temp_assign[4] <= 8'd0;
            temp_assign[5] <= 8'd0;
            temp_assign[6] <= 8'd0;
            temp_assign[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    fail <= 1'b0;
                    idx <= 5'd0;
                    open_count <= 6'd0;
                    close_count <= 6'd0;
                    hash_count <= 4'd0;
                    last_hash_pos <= 4'd0;
                    verification_failed <= 1'b0;
                    if (start) begin
                        state <= COUNT_PAREN;
                    end
                end

                COUNT_PAREN: begin
                    if (idx < length && idx < MAX_LEN) begin
                        if (char_arr[idx] == 2'b00) begin
                            open_count <= open_count + 6'd1;
                        end else if (char_arr[idx] == 2'b01) begin
                            close_count <= close_count + 6'd1;
                        end
                        idx <= idx + 5'd1;
                    end else begin
                        idx <= 5'd0;
                        state <= COUNT_HASH;
                    end
                end

                COUNT_HASH: begin
                    if (idx < length && idx < MAX_LEN) begin
                        if (char_arr[idx] == 2'b10) begin
                            hash_count <= hash_count + 4'd1;
                            last_hash_pos <= idx[3:0];
                        end
                        idx <= idx + 5'd1;
                    end else begin
                        state <= CALC_LAST;
                    end
                end

                CALC_LAST: begin
                    if (hash_count > 4'd8) begin
                        verification_failed <= 1'b1;
                        state <= SET_FAIL;
                    end else begin
                        if (open_count >= close_count + hash_count) begin
                            last_assign <= (open_count - close_count - hash_count) + 8'd2;
                        end else begin
                            verification_failed <= 1'b1;
                            state <= SET_FAIL;
                        end
                        if (last_assign < 8'd1) begin
                            verification_failed <= 1'b1;
                            state <= SET_FAIL;
                        end else begin
                            balance <= 5'd0;
                            idx <= 5'd0;
                            hash_idx <= 3'd0;
                            state <= VERIFY_PRE;
                        end
                    end
                end

                VERIFY_PRE: begin
                    if (idx < length && idx < MAX_LEN) begin
                        if (char_arr[idx] == 2'b00) begin
                            balance <= balance + 5'd1;
                        end else if (char_arr[idx] == 2'b01) begin
                            if (balance > 5'd0) begin
                                balance <= balance - 5'd1;
                            end else begin
                                verification_failed <= 1'b1;
                                state <= SET_FAIL;
                            end
                        end else if (char_arr[idx] == 2'b10) begin
                            if (hash_idx < 3'd7 && hash_idx < hash_count[2:0]) begin
                                assign_val <= 8'd1;
                            end else begin
                                assign_val <= last_assign;
                            end
                            if (balance + {3'd0, assign_val[2:0]} < {3'd0, assign_val[2:0]}) begin
                                verification_failed <= 1'b1;
                                state <= SET_FAIL;
                            end else begin
                                balance <= balance + {3'd0, assign_val[2:0]};
                                hash_idx <= hash_idx + 3'd1;
                            end
                        end
                        idx <= idx + 5'd1;
                    end else begin
                        if (balance != 5'd0) begin
                            verification_failed <= 1'b1;
                            state <= SET_FAIL;
                        end else begin
                            fill_idx <= 3'd0;
                            temp_num_hashes <= hash_count;
                            state <= FILL_ARRAY;
                        end
                    end
                end

                FILL_ARRAY: begin
                    if (fill_idx < 3'd8 && fill_idx < hash_count[2:0]) begin
                        if (fill_idx < hash_count[2:0] - 3'd1) begin
                            temp_assign[fill_idx] <= 8'd1;
                        end else begin
                            temp_assign[fill_idx] <= last_assign;
                        end
                        fill_idx <= fill_idx + 3'd1;
                    end else begin
                        assign_arr[0] <= temp_assign[0];
                        assign_arr[1] <= temp_assign[1];
                        assign_arr[2] <= temp_assign[2];
                        assign_arr[3] <= temp_assign[3];
                        assign_arr[4] <= temp_assign[4];
                        assign_arr[5] <= temp_assign[5];
                        assign_arr[6] <= temp_assign[6];
                        assign_arr[7] <= temp_assign[7];
                        num_hashes <= temp_num_hashes;
                        state <= SET_DONE;
                    end
                end

                SET_DONE: begin
                    done <= 1'b1;
                    fail <= 1'b0;
                    state <= IDLE;
                end

                SET_FAIL: begin
                    done <= 1'b1;
                    fail <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule