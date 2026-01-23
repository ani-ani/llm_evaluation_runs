module interleave_3_arrays (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    input wire [7:0] arr3 [0:7],
    output reg [7:0] result,
    output reg valid,
    output reg done
);

    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] OUTPUT1   = 2'd1;
    localparam [1:0] OUTPUT2   = 2'd2;
    localparam [1:0] OUTPUT3   = 2'd3;

    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] index;
    reg [4:0] out_count;
    reg [4:0] total_outputs;
    reg start_r;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:    next_state = start ? OUTPUT1 : IDLE;
            OUTPUT1: next_state = OUTPUT2;
            OUTPUT2: next_state = OUTPUT3;
            OUTPUT3: begin
                if (index == len - 1 && out_count == total_outputs - 1)
                    next_state = IDLE;
                else if (index == len - 1)
                    next_state = IDLE; // Wait for done signal in IDLE
                else
                    next_state = OUTPUT1;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            out_count <= 5'd0;
            total_outputs <= 5'd0;
            start_r <= 1'b0;
        end else begin
            state <= next_state;
            start_r <= start;
            
            // Default outputs
            valid <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    index <= 4'd0;
                    out_count <= 5'd0;
                    if (start && !start_r) begin
                        total_outputs <= {len, 1'b0} + len; // len * 3
                    end
                end

                OUTPUT1: begin
                    result <= arr1[index];
                    valid <= 1'b1;
                    out_count <= out_count + 5'd1;
                end

                OUTPUT2: begin
                    result <= arr2[index];
                    valid <= 1'b1;
                    out_count <= out_count + 5'd1;
                end

                OUTPUT3: begin
                    result <= arr3[index];
                    valid <= 1'b1;
                    out_count <= out_count + 5'd1;
                    
                    if (index == len - 1) begin
                        if (out_count == total_outputs - 1) begin
                            done <= 1'b1;
                        end
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule