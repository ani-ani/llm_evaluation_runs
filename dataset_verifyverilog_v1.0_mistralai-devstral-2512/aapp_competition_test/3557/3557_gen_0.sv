module train_sabotage_chaos(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] passengers [0:15],
    input wire [3:0] order [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] PROCESS = 4'd2;
    localparam [3:0] CALCULATE = 4'd3;
    localparam [3:0] FINISH = 4'd4;
    
    reg [3:0] state, next_state;
    
    // DSU structures
    reg [3:0] parent [0:15];
    reg [10:0] sum [0:15];
    reg [3:0] rank [0:15];
    
    // Processing control
    reg [3:0] step;
    reg [3:0] current_coach;
    reg [15:0] max_chaos;
    reg [15:0] current_chaos;
    reg [10:0] segment_sums [0:15];
    reg [3:0] segment_count;
    reg [3:0] i, j;
    reg [10:0] temp_sum;
    reg [15:0] temp_chaos;
    
    // Find function with path compression
    function [3:0] find(input [3:0] x);
        if (parent[x] != x) begin
            parent[x] = find(parent[x]);
        end
        find = parent[x];
    endfunction
    
    // Union function
    task union(input [3:0] x, input [3:0] y);
        reg [3:0] root_x, root_y;
        begin
            root_x = find(x);
            root_y = find(y);
            if (root_x != root_y) begin
                if (rank[root_x] < rank[root_y]) begin
                    parent[root_x] = root_y;
                    sum[root_y] = sum[root_x] + sum[root_y];
                end else if (rank[root_x] > rank[root_y]) begin
                    parent[root_y] = root_x;
                    sum[root_x] = sum[root_x] + sum[root_y];
                end else begin
                    parent[root_y] = root_x;
                    sum[root_x] = sum[root_x] + sum[root_y];
                    rank[root_x] = rank[root_x] + 1'b1;
                end
            end
        end
    endtask
    
    // Round up to nearest 10
    function [10:0] round_up(input [10:0] value);
        reg [10:0] remainder;
        begin
            remainder = value % 10'd10;
            if (remainder != 0) begin
                round_up = value + (10'd10 - remainder);
            end else begin
                round_up = value;
            end
        end
    endfunction
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            max_chaos <= 16'd0;
            step <= 4'd0;
            current_coach <= 4'd0;
            
            // Initialize DSU
            for (i = 0; i < 16; i = i + 1) begin
                parent[i] <= i;
                sum[i] <= 11'd0;
                rank[i] <= 2'd0;
            end
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = PROCESS;
                step = 4'd0;
                current_coach = order[15];
                max_chaos = 16'd0;
            end
            
            PROCESS: begin
                if (step == 15) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            CALCULATE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
                done = 1'b1;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Processing logic
    always @(posedge clk) begin
        if (state == PROCESS) begin
            // Add current coach
            parent[current_coach] = current_coach;
            sum[current_coach] = passengers[current_coach];
            
            // Check left neighbor
            if (current_coach > 0 && parent[current_coach - 1] != 16'd0) begin
                union(current_coach, current_coach - 1);
            end
            
            // Check right neighbor
            if (current_coach < 15 && parent[current_coach + 1] != 16'd0) begin
                union(current_coach, current_coach + 1);
            end
            
            // Calculate current chaos
            current_chaos = 16'd0;
            segment_count = 4'd0;
            
            // Find all unique roots
            for (i = 0; i < 16; i = i + 1) begin
                if (parent[i] != 16'd0) begin
                    segment_sums[i] = 11'd0;
                end
            end
            
            for (i = 0; i < 16; i = i + 1) begin
                if (parent[i] != 16'd0) begin
                    temp_sum = sum[find(i)];
                    if (temp_sum > 0) begin
                        segment_sums[find(i)] = temp_sum;
                    end
                end
            end
            
            // Calculate total chaos
            temp_chaos = 16'd0;
            segment_count = 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (segment_sums[i] > 0) begin
                    temp_chaos = temp_chaos + round_up(segment_sums[i]);
                    segment_count = segment_count + 1'b1;
                end
            end
            
            current_chaos = temp_chaos * segment_count;
            
            // Update max chaos
            if (current_chaos > max_chaos) begin
                max_chaos = current_chaos;
            end
            
            // Move to next step
            step = step + 1'b1;
            current_coach = order[15 - step];
        end else if (state == CALCULATE) begin
            result = max_chaos;
        end else if (state == FINISH) begin
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end
    
    // Reset done signal
    always @(posedge clk) begin
        if (state != FINISH) begin
            done = 1'b0;
        end
    end

endmodule