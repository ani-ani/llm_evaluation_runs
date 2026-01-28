module tuple_length_comparator(
    input clk,
    input rst_n,
    input start,
    input [3:0] tuple_lengths [0:7],
    output reg equal,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;
    
    reg [3:0] latched_lengths [0:7];
    integer i;
    reg all_equal;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            equal <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                latched_lengths[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Latch the tuple lengths
                        for (i = 0; i < 8; i = i + 1) begin
                            latched_lengths[i] <= tuple_lengths[i];
                        end
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    all_equal = 1'b1;
                    
                    // Compare all tuples against the first one
                    for (i = 1; i < 8; i = i + 1) begin
                        if (latched_lengths[i] != latched_lengths[0]) begin
                            all_equal = 1'b0;
                        end
                    end
                    
                    equal <= all_equal;
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES || all_equal === 1'b1 || all_equal === 1'b0) begin
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