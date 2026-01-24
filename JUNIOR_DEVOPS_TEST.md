# Intern/Junior DevOps Engineer Technical Assessment

### Your Coding Challenge: Should you choose to accept it

Welcome! We've designed this exercise to be a fun and engaging way for you to showcase your skills in software engineering, DevOps, and infrastructure.

Don't feel pressured to complete every single task. We want to see how you approach problems, where you're comfortable, and where you're excited to learn. The goal is for you to have a great time and show us what you can do.

If you have any questions or get stuck, please don't hesitate to ask for help! We're here to support you.

---

### The Tasks

This exercise is broken down into several clear steps. Think of it as building a project, one component at a time.

#### Task 0: Get Your Own Project Space

First, you need a private space to work on your code.

* **Fork this repository** into a **private** repository under your own account.
* Once you're ready, add **ileriayo** user as a **Reporter** (in your repository settings). This allows our team to view your code without you having to make it public.
* Finally, reply to our email with a link to your new private repository.

#### Task 1: Grab the API

We've provided an API, built with the Python programming language.

* Go to **https://github.com/PipeOpsHQ/titanic-api**.
* Copy the Python implementation of the API into your new repository. Feel free to make any changes to the code you think are necessary, but don't waste your time!

#### Task 2: Set Up and Populate the Database

The API needs data to work.

* A dataset is provided in the **`titanic.csv`** file.
* Create a database (you can use SQL or NoSQL—it's your choice!) and load the data from the CSV file into it.

#### Task 3: Package Your Application with Docker

Now, let's make your application easy to run anywhere.

* **Containerize your application** components using Docker.
* So that you can run the entire application with just one or two commands, making it portable and easy to share.

#### Task 4: Deploy to Kubernetes

Take your Docker containers and deploy them to a Kubernetes cluster.

* If you don't have a cluster to test against, here are some great free options:
    * **MiniKube** (for a local cluster on your machine)
    * **Docker Desktop's built-in Kubernetes**
* For a more realistic test, you could use a cloud provider like **EKS** (Elastic Kubernetes Service), **AKS** (Azure Kubernetes Service), or **GKE** (Google Kubernetes Engine), but be aware of potential costs.
* Make sure your code and scripts work on both Linux and macOS.

#### Task 5: Go Above and Beyond!

This is your chance to shine and show us what you're passionate about. Do you have any ideas for how to improve the setup or add more features? Feel free to try something new!

Here are a few suggestions if you need inspiration:

* **Implement a CI/CD pipeline** to automate the build and deployment process.
* **Add a logging or monitoring system** to track your application's performance.
* **Scan your Docker image** for security vulnerabilities.

We're excited to see your solution!
