module ElementwiseMultiplier2D (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    output reg [15:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [2:0] index;  // 0-7 for 8 elements
    reg [2:0] index_next;
    reg [15:0] temp_result [0:7];
    reg [2:0] i;  // Loop variable
    
    // Sequential state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 16'd0;
                temp_result[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            index <= index_next;
            // Store intermediate results during compute
            if (state == COMPUTE) begin
                temp_result[index] <= arr1[index] * arr2[index];
            end
            // Pass results to output on finish
            if (state == FINISH) begin
                for (i = 0; i < 8; i = i + 1) begin
                    result[i] <= temp_result[i];
                end
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        index_next = index;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    index_next = 3'd0;
                end
            end
            
            COMPUTE: begin
                if (index < 3'd7) begin
                    index_next = index + 3'd1;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
                index_next = 3'd0;
            end
            
            default: begin
                next_state = IDLE;
                index_next = 3'd0;
            end
        endcase
    end

endmodule