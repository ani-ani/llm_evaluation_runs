module cinema_seating (
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [1:0] c1, c2, c3,
    output reg [2:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic for result calculation
    always @(*) begin
        // Default: impossible
        result = 3'd5;
        case ({n, c3, c2, c1})
            // n = 1 (2'b01)
            8'b01_00_00_00: result = 3'd1;
            8'b01_00_00_01: result = 3'd1;
            8'b01_00_00_02: result = 3'd2;
            // n = 2 (2'b10)
            8'b10_00_00_00: result = 3'd1;
            8'b10_00_00_01: result = 3'd1;
            8'b10_00_00_02: result = 3'd2;
            8'b10_00_01_00: result = 3'd2;
            8'b10_00_01_01: result = 3'd2;
            8'b10_00_01_02: result = 3'd3;
            8'b10_00_02_00: result = 3'd3;
            8'b10_00_02_01: result = 3'd3;
            8'b10_00_02_02: result = 3'd4;
            // n = 3 (2'b11)
            8'b11_00_00_01: result = 3'd1;
            8'b11_00_00_02: result = 3'd2;
            8'b11_00_01_00: result = 3'd2;
            8'b11_00_01_01: result = 3'd2;
            8'b11_00_01_02: result = 3'd3;
            8'b11_00_02_00: result = 3'd3;
            8'b11_00_02_01: result = 3'd3;
            8'b11_00_02_02: result = 3'd4;
            8'b11_01_00_00: result = 3'd3;
            8'b11_01_00_01: result = 3'd3;
            8'b11_01_00_02: result = 3'd3;
            8'b11_01_01_00: result = 3'd3;
            8'b11_01_01_01: result = 3'd3;
            8'b11_01_01_02: result = 3'd4;
            8'b11_01_02_00: result = 3'd4;
            8'b11_01_02_01: result = 3'd4;
            8'b11_01_02_02: result = 3'd4;
            8'b11_02_00_00: result = 3'd4;
            8'b11_02_00_01: result = 3'd4;
            8'b11_02_00_02: result = 3'd4;
            8'b11_02_01_00: result = 3'd4;
            8'b11_02_01_01: result = 3'd4;
            default: result = 3'd5;
        endcase
        // Override: if n == 0, treat as impossible
        if (n == 2'd0) result = 3'd5;
    end

    // Sequential logic for state machine and done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
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