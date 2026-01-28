module star_wars_ordering (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] q_type,  // 1=insert, 2=query
    input wire [4:0] x,       // plot index (1-16)
    output reg [4:0] result,  // creation index for query
    output reg done
);

    // Maximum 16 movies, 64 operations
    parameter MAX_MOVIES = 16;
    parameter MAX_OPS = 64;
    
    // Internal state
    reg [4:0] plot_order [0:15];  // Creation index at each plot position
    reg [4:0] creation_count;      // Number of movies created
    reg [5:0] op_count;            // Operation counter
    
    // FSM states
    reg [1:0] state;
    localparam IDLE = 2'd0;
    localparam EXECUTE = 2'd1;
    localparam COMPLETE = 2'd2;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            for (i = 0; i < 16; i = i + 1) begin
                plot_order[i] <= 5'd0;
            end
            creation_count <= 5'd0;
            op_count <= 6'd0;
            result <= 5'd0;
            done <= 1'b0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && op_count < MAX_OPS) begin
                        op_count <= op_count + 1'b1;
                        state <= EXECUTE;
                    end
                end
                
                EXECUTE: begin
                    if (q_type == 2'd1) begin
                        // INSERT: create movie at plot index x
                        if (creation_count < MAX_MOVIES && x >= 1 && x <= creation_count + 1) begin
                            // Shift movies with plot index >= x to the right
                            for (i = creation_count; i >= x; i = i - 1) begin
                                if (i < 15) plot_order[i] <= plot_order[i - 1];
                            end
                            // Insert new movie at position x-1 (0-indexed)
                            plot_order[x - 1] <= creation_count + 1;
                            creation_count <= creation_count + 1'b1;
                        end
                    end else if (q_type == 2'd2) begin
                        // QUERY: get creation index at plot index x
                        if (x >= 1 && x <= creation_count) begin
                            result <= plot_order[x - 1];
                        end
                    end
                    state <= COMPLETE;
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule