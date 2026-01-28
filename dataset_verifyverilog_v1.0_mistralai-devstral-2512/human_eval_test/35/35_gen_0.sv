module max_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Comparator tree for 8 elements
    wire [7:0] max_0_1;
    wire [7:0] max_2_3;
    wire [7:0] max_4_5;
    wire [7:0] max_6_7;
    wire [7:0] max_0_3;
    wire [7:0] max_4_7;
    wire [7:0] max_final;

    // First level comparators
    assign max_0_1 = (arr[0] > arr[1]) ? arr[0] : arr[1];
    assign max_2_3 = (arr[2] > arr[3]) ? arr[2] : arr[3];
    assign max_4_5 = (arr[4] > arr[5]) ? arr[4] : arr[5];
    assign max_6_7 = (arr[6] > arr[7]) ? arr[6] : arr[7];

    // Second level comparators
    assign max_0_3 = (max_0_1 > max_2_3) ? max_0_1 : max_2_3;
    assign max_4_7 = (max_4_5 > max_6_7) ? max_4_5 : max_6_7;

    // Final comparator
    assign max_final = (max_0_3 > max_4_7) ? max_0_3 : max_4_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
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
                    result <= max_final;
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