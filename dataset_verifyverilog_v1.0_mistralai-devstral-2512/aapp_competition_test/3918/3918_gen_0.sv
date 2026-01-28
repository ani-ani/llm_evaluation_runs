module minimize_array_error(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] A_in [0:7],
    input wire signed [7:0] B_in [0:7],
    input wire [8:0] K_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] SUM = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Registers for differences
    reg [7:0] d [0:7];
    
    // K counter
    reg [8:0] k_counter;
    
    // Index of maximum difference
    reg [2:0] max_idx;
    
    // Temporary result accumulation
    reg [31:0] sum_result;
    
    // Current operation index
    reg [2:0] op_idx;
    
    // Find maximum index logic
    always @(*) begin
        reg [7:0] max_val = 8'd0;
        reg [2:0] idx = 3'd0;
        
        for (op_idx = 0; op_idx < 8; op_idx = op_idx + 1) begin
            if (d[op_idx] > max_val) begin
                max_val = d[op_idx];
                idx = op_idx;
            end
        end
        
        max_idx = idx;
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            sum_result <= 32'd0;
            k_counter <= 9'd0;
            
            // Initialize d array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                d[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (k_counter == K_in) begin
                    next_state = SUM;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            SUM: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Load differences
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in main reset
        end else begin
            if (state == LOAD) begin
                integer i;
                for (i = 0; i < 8; i = i + 1) begin
                    // Compute absolute difference
                    if (A_in[i] > B_in[i]) begin
                        d[i] <= A_in[i] - B_in[i];
                    end else begin
                        d[i] <= B_in[i] - A_in[i];
                    end
                end
                k_counter <= 9'd0;
            end
        end
    end

    // Compute operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else begin
            if (state == COMPUTE) begin
                // Decrement the maximum difference
                if (d[max_idx] > 8'd0) begin
                    d[max_idx] <= d[max_idx] - 8'd1;
                end else begin
                    d[max_idx] <= 8'd1;
                end
                
                // Increment operation counter
                k_counter <= k_counter + 9'd1;
            end
        end
    end

    // Sum squares
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else begin
            if (state == SUM) begin
                integer i;
                reg [15:0] square;
                
                sum_result <= 32'd0;
                
                for (i = 0; i < 8; i = i + 1) begin
                    square = d[i] * d[i];
                    sum_result <= sum_result + square;
                end
                
                result <= sum_result;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule