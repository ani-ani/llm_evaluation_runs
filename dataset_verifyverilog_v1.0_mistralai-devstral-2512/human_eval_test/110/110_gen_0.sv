module exchange_check(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:15],
    input wire [7:0] arr2 [0:15],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CALCULATE = 2'd1;
    localparam [1:0] FINISH    = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] odd1_count;
    reg [3:0] even2_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            odd1_count <= 4'd0;
            even2_count <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CALCULATE;
                        index <= 4'd0;
                        odd1_count <= 4'd0;
                        even2_count <= 4'd0;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check parity of arr1[index]
                    if (arr1[index][0] == 1'b1) begin
                        odd1_count <= odd1_count + 4'd1;
                    end

                    // Check parity of arr2[index]
                    if (arr2[index][0] == 1'b0) begin
                        even2_count <= even2_count + 4'd1;
                    end

                    // Move to next index or finish
                    if (index == len - 4'd1 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                FINISH: begin
                    // Compute result
                    if (odd1_count <= even2_count) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule