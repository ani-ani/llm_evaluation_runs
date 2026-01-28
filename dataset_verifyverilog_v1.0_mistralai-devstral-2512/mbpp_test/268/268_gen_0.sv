module star_number (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE  = 3'd0;
    localparam [2:0] CALC1 = 3'd1;
    localparam [2:0] CALC2 = 3'd2;
    localparam [2:0] CALC3 = 3'd3;
    localparam [2:0] DONE  = 3'd4;

    reg [2:0] state;
    reg [15:0] temp1;
    reg [15:0] temp2;
    reg [15:0] temp3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            temp1 <= 16'd0;
            temp2 <= 16'd0;
            temp3 <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC1;
                    end
                end

                CALC1: begin
                    // Compute temp1 = n - 1 (5-bit subtraction)
                    temp1 <= {11'b0, n} - 16'd1;
                    // Compute temp2 = 6 * n (16-bit)
                    temp2 <= 16'd6 * {11'b0, n};
                    state <= CALC2;
                end

                CALC2: begin
                    // Compute temp3 = temp2 * temp1 (16-bit)
                    temp3 <= temp2 * temp1;
                    state <= CALC3;
                end

                CALC3: begin
                    // Compute result = temp3 + 1
                    result <= temp3 + 16'd1;
                    state <= DONE;
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