module table_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] A,
    input wire [31:0] B,
    output reg [31:0] result,
    output reg done
);

    // State machine encoding
    localparam [2:0] S_IDLE = 3'b000;
    localparam [2:0] S_INIT_ROW = 3'b001;
    localparam [2:0] S_CHECK = 3'b010;
    localparam [2:0] S_GEN_NEXT = 3'b011;
    localparam [2:0] S_NEXT_ROW = 3'b100;
    localparam [2:0] S_FINISH = 3'b101;

    // Internal registers
    reg [2:0] state;
    reg [31:0] row_idx;
    reg [31:0] current_val;
    reg [31:0] count_acc;
    reg [5:0] step_count;

    // Helper function to reverse digits
    function [31:0] rev;
        input [31:0] x;
        reg [31:0] r, t;
        integer j;
        begin
            r = 0; t = x;
            for (j = 0; j < 10; j = j + 1) begin
                if (t == 0) begin
                    j = 10;
                end else begin
                    r = r * 10 + (t % 10);
                    t = t / 10;
                end
            end
            rev = r;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            row_idx <= 32'd1;
            current_val <= 32'd0;
            count_acc <= 32'd0;
            step_count <= 6'd0;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        row_idx <= 32'd1;
                        count_acc <= 32'd0;
                        state <= S_INIT_ROW;
                    end
                end

                S_INIT_ROW: begin
                    step_count <= 6'd0;
                    if (row_idx > B || row_idx > 200) begin
                        state <= S_FINISH;
                        result <= count_acc;
                        done <= 1'b1;
                    end else begin
                        current_val <= row_idx;
                        state <= S_CHECK;
                    end
                end

                S_CHECK: begin
                    if (current_val >= A && current_val <= B) begin
                        count_acc <= count_acc + 32'd1;
                    end
                    step_count <= step_count + 6'd1;
                    state <= S_GEN_NEXT;
                end

                S_GEN_NEXT: begin
                    current_val <= current_val + rev(current_val);
                    if (current_val > B || step_count >= 20) begin
                        row_idx <= row_idx + 32'd1;
                        state <= S_INIT_ROW;
                    end else begin
                        state <= S_CHECK;
                    end
                end

                S_FINISH: begin
                    if (!start) begin
                        state <= S_IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule