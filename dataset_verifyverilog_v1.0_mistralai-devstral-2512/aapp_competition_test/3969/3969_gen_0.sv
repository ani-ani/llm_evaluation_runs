module LISAccelerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] species_in,
    input wire valid_in,
    input wire [7:0] len_in,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] RECEIVE   = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Input tracking
    reg [7:0] count;
    reg [7:0] max_count;
    
    // Sequence storage (256 elements max)
    reg [3:0] sequence [0:255];
    
    // LIS computation variables
    reg [7:0] lis_length;
    reg [7:0] i, j;
    reg [7:0] dp [0:255];
    reg [7:0] current_max;
    
    // Cycle counter for safety
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 8'd0;
            max_count <= 8'd0;
            lis_length <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            current_max <= 8'd0;
            cycle_count <= 10'd0;
            result <= 16'd0;
            done <= 1'b0;
            
            // Initialize sequence and dp arrays
            integer k;
            for (k = 0; k < 256; k = k + 1) begin
                sequence[k] <= 4'd0;
                dp[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        max_count <= len_in;
                        count <= 8'd0;
                        next_state <= RECEIVE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                RECEIVE: begin
                    if (valid_in && count < max_count) begin
                        sequence[count] <= species_in;
                        count <= count + 8'd1;
                    end
                    
                    if (count == max_count) begin
                        // Initialize dp array
                        integer k;
                        for (k = 0; k < 256; k = k + 1) begin
                            dp[k] <= 8'd1;
                        end
                        
                        i <= 8'd0;
                        j <= 8'd0;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= RECEIVE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    if (i < max_count) begin
                        if (j < i) begin
                            // Compare sequence[j] and sequence[i]
                            if (sequence[j] <= sequence[i]) begin
                                if (dp[j] + 8'd1 > dp[i]) begin
                                    dp[i] <= dp[j] + 8'd1;
                                end
                            end
                            j <= j + 8'd1;
                        end else begin
                            // Move to next i
                            i <= i + 8'd1;
                            j <= 8'd0;
                        end
                    end else begin
                        // Find maximum in dp array
                        current_max <= 8'd0;
                        integer k;
                        for (k = 0; k < 256; k = k + 1) begin
                            if (dp[k] > current_max) begin
                                current_max <= dp[k];
                            end
                        end
                        
                        lis_length <= current_max;
                        next_state <= FINISH;
                    end
                    
                    // Safety check for infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= {8'd0, lis_length};
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
endmodule