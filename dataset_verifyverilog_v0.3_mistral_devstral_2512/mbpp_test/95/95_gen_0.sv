module Find_Min_Length #(
    parameter NUM_LISTS = 4,
    parameter MAX_LEN = 8,
    parameter LEN_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [LEN_WIDTH-1:0] lengths [0:NUM_LISTS-1],
    output reg [LEN_WIDTH-1:0] min_length,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [LEN_WIDTH-1:0] current_min;
    reg [$clog2(NUM_LISTS)-1:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_length <= {LEN_WIDTH{1'b0}};
            done <= 1'b0;
            current_min <= {LEN_WIDTH{1'b0}};
            index <= {$clog2(NUM_LISTS){1'b0}};
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        index <= {$clog2(NUM_LISTS){1'b0}};
                        current_min <= lengths[0];
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (index == NUM_LISTS - 1) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 1'b1;
                        if (lengths[index] < current_min) begin
                            current_min <= lengths[index];
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    min_length <= current_min;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule