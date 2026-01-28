module second_smallest_fixed_point(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr [0:7],
    input wire [7:0] valid_in,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] SCAN   = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [7:0] index;
    reg signed [15:0] smallest;
    reg signed [15:0] second_smallest;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 8'd0;
            smallest <= 16'd0;
            second_smallest <= 16'd0;
            result <= 16'hFFFF;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SCAN;
                        index <= 8'd0;
                        smallest <= 16'h7FFF;  // Initialize to max positive Q8.8
                        second_smallest <= 16'h7FFF;
                    end
                end

                SCAN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (index < 8'd8) begin
                        if (valid_in[index] && arr[index] < smallest) begin
                            second_smallest <= smallest;
                            smallest <= arr[index];
                        end else if (valid_in[index] && arr[index] > smallest && arr[index] < second_smallest) begin
                            second_smallest <= arr[index];
                        end
                        
                        index <= index + 8'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    if (second_smallest == 16'h7FFF) begin
                        result <= 16'hFFFF;  // No second smallest found
                    end else begin
                        result <= second_smallest;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule