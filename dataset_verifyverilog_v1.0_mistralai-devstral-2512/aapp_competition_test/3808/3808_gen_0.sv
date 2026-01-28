module bracket_checker(
    input clk,
    input rst_n,
    input start,
    input [127:0] seq_in,
    input [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] COUNT  = 2'd1;
    localparam [1:0] CHECK  = 2'd2;
    localparam [1:0] DONE   = 2'd3;

    reg [1:0] state;
    reg [7:0] balance;
    reg [7:0] min_balance;
    reg [3:0] index;
    reg [3:0] open_count;
    reg [3:0] close_count;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            balance <= 8'd0;
            min_balance <= 8'd0;
            index <= 4'd0;
            open_count <= 4'd0;
            close_count <= 4'd0;
            cycle_count <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        if (seq_in[(index * 8) + 7 : index * 8] == 8'd40) begin
                            open_count <= open_count + 4'd1;
                        end else if (seq_in[(index * 8) + 7 : index * 8] == 8'd41) begin
                            close_count <= close_count + 4'd1;
                        end
                        index <= index + 4'd1;
                    end else begin
                        index <= 4'd0;
                        if (open_count == close_count) begin
                            state <= CHECK;
                        end else begin
                            result <= 1'b0;
                            state <= DONE;
                        end
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (index < len) begin
                        if (seq_in[(index * 8) + 7 : index * 8] == 8'd40) begin
                            balance <= balance + 8'd1;
                        end else if (seq_in[(index * 8) + 7 : index * 8] == 8'd41) begin
                            balance <= balance - 8'd1;
                        end
                        if (balance < min_balance) begin
                            min_balance <= balance;
                        end
                        if (balance < -8'd2) begin
                            result <= 1'b0;
                            state <= DONE;
                        end else begin
                            index <= index + 4'd1;
                        end
                    end else begin
                        if (balance == 8'd0 && min_balance >= -8'd1) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule