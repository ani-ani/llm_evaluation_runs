module identical_element_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [7:0] list3 [0:7],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Parallel comparison signals
    reg [7:0] match_counts;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                match_counts[i] <= 1'b0;
            end
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
                    
                    // Parallel comparison for all positions
                    for (i = 0; i < 8; i = i + 1) begin
                        match_counts[i] <= (list1[i] == list2[i]) && (list2[i] == list3[i]);
                    end
                    
                    // Sum all matches
                    result <= match_counts[0] + match_counts[1] + match_counts[2] + match_counts[3] +
                              match_counts[4] + match_counts[5] + match_counts[6] + match_counts[7];
                    
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