module TreasureSolver(
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
    localparam [3:0] MAX_HASHES = 4'd8;
    localparam [1:0] CHAR_WIDTH = 2'd2;

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT = 3'd1;
    localparam [2:0] CALC = 3'd2;
    localparam [2:0] VERIFY = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] FAIL = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [3:0] open_count;
    reg [3:0] close_count;
    reg [3:0] hash_count;
    reg [3:0] last_hash_pos;
    reg [7:0] last_assign;
    reg [7:0] balance;
    reg [7:0] temp_assign_arr [0:7];
    reg valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            open_count <= 4'd0;
            close_count <= 4'd0;
            hash_count <= 4'd0;
            last_hash_pos <= 4'd0;
            last_assign <= 8'd0;
            balance <= 8'd0;
            done <= 1'b0;
            fail <= 1'b0;
            num_hashes <= 4'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                assign_arr[i] <= 8'd0;
                temp_assign_arr[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    fail <= 1'b0;
                    if (start) begin
                        index <= 4'd0;
                        open_count <= 4'd0;
                        close_count <= 4'd0;
                        hash_count <= 4'd0;
                        last_hash_pos <= 4'd0;
                        last_assign <= 8'd0;
                        balance <= 8'd0;
                        next_state <= COUNT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COUNT: begin
                    if (index < length) begin
                        case (char_arr[index])
                            2'd0: open_count <= open_count + 4'd1;
                            2'd1: close_count <= close_count + 4'd1;
                            2'd2: begin
                                hash_count <= hash_count + 4'd1;
                                last_hash_pos <= index;
                            end
                            default: ;
                        endcase
                        index <= index + 4'd1;
                        next_state <= COUNT;
                    end else begin
                        next_state <= CALC;
                    end
                end

                CALC: begin
                    last_assign <= open_count - close_count - hash_count + 8'd2;
                    if (last_assign >= 8'd1) begin
                        next_state <= VERIFY;
                    end else begin
                        next_state <= FAIL;
                    end
                end

                VERIFY: begin
                    if (index < length) begin
                        case (char_arr[index])
                            2'd0: balance <= balance + 8'd1;
                            2'd1: balance <= balance - 8'd1;
                            2'd2: begin
                                if (index == last_hash_pos) begin
                                    balance <= balance + last_assign;
                                end else begin
                                    balance <= balance + 8'd1;
                                end
                            end
                            default: ;
                        endcase
                        index <= index + 4'd1;
                        next_state <= VERIFY;
                    end else begin
                        if (balance == 8'd0) begin
                            next_state <= OUTPUT;
                        end else begin
                            next_state <= FAIL;
                        end
                    end
                end

                OUTPUT: begin
                    for (integer i = 0; i < 8; i = i + 1) begin
                        if (i < hash_count) begin
                            if (i == hash_count - 4'd1) begin
                                temp_assign_arr[i] <= last_assign;
                            end else begin
                                temp_assign_arr[i] <= 8'd1;
                            end
                        end else begin
                            temp_assign_arr[i] <= 8'd0;
                        end
                    end
                    num_hashes <= hash_count;
                    done <= 1'b1;
                    fail <= 1'b0;
                    next_state <= IDLE;
                end

                FAIL: begin
                    done <= 1'b1;
                    fail <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    always @(posedge clk) begin
        for (integer i = 0; i < 8; i = i + 1) begin
            assign_arr[i] <= temp_assign_arr[i];
        end
    end

endmodule