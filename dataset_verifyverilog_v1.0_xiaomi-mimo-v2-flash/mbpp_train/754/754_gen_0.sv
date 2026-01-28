module FindCommonElements (
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

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] temp_result [0:7];
    reg [3:0] temp_len;
    reg [2:0] i; // Index counter
    
    // Combinational comparison logic
    always @(*) begin
        temp_len = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
            temp_result[i] = 8'd0;
        end
        for (i = 0; i < 8; i = i + 1) begin
            if ((l1[i] == l2[i]) && (l1[i] == l3[i])) begin
                temp_result[temp_len] = l1[i];
                temp_len = temp_len + 4'd1;
            end
        end
    end
    
    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
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
                    // Register the combinational results
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= temp_result[i];
                    end
                    result_len <= temp_len;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule