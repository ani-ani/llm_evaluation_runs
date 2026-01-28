module common_elements_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] l1 [0:7],
    input [7:0] l2 [0:7],
    input [7:0] l3 [0:7],
    output reg [7:0] result [0:7],
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [7:0] i;
    reg [7:0] match_count;
    reg [7:0] temp_result [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            i <= 8'd0;
            match_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
                temp_result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    // Perform comparisons
                    for (i = 0; i < 8; i = i + 1) begin
                        if (l1[i] == l2[i] && l2[i] == l3[i]) begin
                            temp_result[i] <= l1[i];
                            match_count <= match_count + 8'd1;
                        end else begin
                            temp_result[i] <= 8'd0;
                        end
                    end
                    
                    // Register results
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= temp_result[i];
                    end
                    result_len <= match_count[3:0];
                    
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