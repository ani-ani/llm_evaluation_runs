module governor_party_converter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] m,
    input wire [99:0] initial_parties,
    input wire [9:0] friendship_a,
    input wire [9:0] friendship_b,
    output reg [7:0] min_months,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] current_months;
    reg [7:0] current_parties [0:99];
    reg [7:0] temp_parties [0:99];
    reg [7:0] node_index;
    reg [7:0] neighbor_index;
    reg [7:0] flip_count;
    reg [7:0] max_flips;
    reg [7:0] i, j;
    reg [15:0] timeout_counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_months <= 8'd0;
            done <= 1'b0;
            timeout_counter <= 16'd0;
        end else begin
            state <= next_state;
            timeout_counter <= timeout_counter + 1'b1;
            
            // Timeout protection
            if (timeout_counter > 16'd1000) begin
                state <= DONE_STATE;
                min_months <= 8'd0;
                done <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = PROCESS;
            end
            PROCESS: begin
                if (flip_count >= max_flips || current_months > 8'd100) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk) begin
        if (state == LOAD) begin
            // Initialize parties
            for (i = 0; i < 100; i = i + 1) begin
                current_parties[i] <= initial_parties[i];
                temp_parties[i] <= initial_parties[i];
            end
            current_months <= 8'd0;
            flip_count <= 8'd0;
            max_flips <= 8'd100;
        end
        else if (state == PROCESS) begin
            // Check if all parties are the same
            reg all_same;
            all_same = 1'b1;
            for (i = 1; i < n; i = i + 1) begin
                if (current_parties[i] != current_parties[0]) begin
                    all_same = 1'b0;
                end
            end
            
            if (all_same) begin
                min_months <= current_months;
                done <= 1'b1;
            end else begin
                // Find a node to flip
                node_index <= 8'd0;
                for (i = 0; i < n; i = i + 1) begin
                    if (current_parties[i] != current_parties[0]) begin
                        node_index <= i;
                        break;
                    end
                end
                
                // Flip the node
                temp_parties[node_index] <= current_parties[0];
                
                // Check if this flip helps
                reg improved;
                improved = 1'b0;
                for (j = 0; j < n; j = j + 1) begin
                    if (temp_parties[j] != temp_parties[0]) begin
                        improved = 1'b0;
                        break;
                    end
                end
                
                if (improved) begin
                    // Copy temp to current
                    for (j = 0; j < n; j = j + 1) begin
                        current_parties[j] <= temp_parties[j];
                    end
                    current_months <= current_months + 8'd1;
                    flip_count <= 8'd0;
                end else begin
                    flip_count <= flip_count + 8'd1;
                end
            end
        end
        else if (state == DONE_STATE) begin
            done <= 1'b1;
        end
    end

endmodule