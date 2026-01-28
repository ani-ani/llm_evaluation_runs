module meow_transform(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire last_char,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] char_buffer [0:1];
    reg [7:0] prev_char;
    reg [7:0] current_char;
    
    // DP states: cost to match prefixes of 'meow'
    reg [7:0] dp_cost [0:4]; // dp_cost[0] = "", dp_cost[1] = "m", dp_cost[2] = "me", dp_cost[3] = "meo", dp_cost[4] = "meow"
    
    // Target string "meow"
    localparam [7:0] TARGET [0:4] = '{8'd0, "m", "e", "o", "w"};
    
    // Counter for input characters
    reg [3:0] char_count;
    
    // Initialize DP costs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_count <= 4'd0;
            prev_char <= 8'd0;
            current_char <= 8'd0;
            char_buffer[0] <= 8'd0;
            char_buffer[1] <= 8'd0;
            
            // Initialize DP costs
            dp_cost[0] <= 8'd0; // Empty prefix cost
            dp_cost[1] <= 8'd255; // "m" prefix cost
            dp_cost[2] <= 8'd255; // "me" prefix cost
            dp_cost[3] <= 8'd255; // "meo" prefix cost
            dp_cost[4] <= 8'd255; // "meow" prefix cost
            
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        char_count <= 4'd0;
                        prev_char <= 8'd0;
                        current_char <= 8'd0;
                        char_buffer[0] <= 8'd0;
                        char_buffer[1] <= 8'd0;
                        
                        // Reset DP costs
                        dp_cost[0] <= 8'd0;
                        dp_cost[1] <= 8'd255;
                        dp_cost[2] <= 8'd255;
                        dp_cost[3] <= 8'd255;
                        dp_cost[4] <= 8'd255;
                    end
                end
                
                PROCESS: begin
                    if (char_valid) begin
                        // Shift buffer
                        char_buffer[0] <= char_buffer[1];
                        char_buffer[1] <= char_in;
                        
                        // Update previous and current characters
                        prev_char <= current_char;
                        current_char <= char_in;
                        
                        // Update DP costs for current character
                        update_dp_costs;
                        
                        // Increment character count
                        char_count <= char_count + 4'd1;
                    end
                    
                    if (last_char) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Find minimum cost among all DP states
                    reg [7:0] min_cost;
                    integer i;
                    
                    min_cost <= dp_cost[0];
                    for (i = 1; i < 5; i = i + 1) begin
                        if (dp_cost[i] < min_cost) begin
                            min_cost <= dp_cost[i];
                        end
                    end
                    
                    result <= {8'd0, min_cost};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Task to update DP costs
    task update_dp_costs;
        reg [7:0] new_dp_cost [0:4];
        integer j;
        
        // Initialize new costs with current costs
        for (j = 0; j < 5; j = j + 1) begin
            new_dp_cost[j] <= dp_cost[j];
        end
        
        // Delete operation: add 1 to all costs
        for (j = 0; j < 5; j = j + 1) begin
            if (dp_cost[j] + 8'd1 < new_dp_cost[j]) begin
                new_dp_cost[j] <= dp_cost[j] + 8'd1;
            end
        end
        
        // Replace/Match operation
        for (j = 0; j < 4; j = j + 1) begin
            if (current_char == TARGET[j+1]) begin
                if (dp_cost[j] < new_dp_cost[j+1]) begin
                    new_dp_cost[j+1] <= dp_cost[j];
                end
            end else begin
                if (dp_cost[j] + 8'd1 < new_dp_cost[j+1]) begin
                    new_dp_cost[j+1] <= dp_cost[j] + 8'd1;
                end
            end
        end
        
        // Insert operation: add 1 to previous costs
        for (j = 0; j < 4; j = j + 1) begin
            if (dp_cost[j] + 8'd1 < new_dp_cost[j+1]) begin
                new_dp_cost[j+1] <= dp_cost[j] + 8'd1;
            end
        end
        
        // Swap operation: check if previous and current can be swapped to match target
        if (char_count > 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                if (prev_char == TARGET[j+1] && current_char == TARGET[j]) begin
                    if (dp_cost[j] + 8'd1 < new_dp_cost[j+1]) begin
                        new_dp_cost[j+1] <= dp_cost[j] + 8'd1;
                    end
                end
            end
        end
        
        // Update DP costs
        for (j = 0; j < 5; j = j + 1) begin
            dp_cost[j] <= new_dp_cost[j];
        end
    endtask
    
endmodule